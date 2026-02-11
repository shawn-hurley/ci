#!/usr/bin/env python3
"""
Parse nightly matrix config YAML and organize jobs by dependency levels.

This script reads a YAML configuration file and creates a multi-level array
where each level represents a dependency depth in the job tree.
"""

import sys
import json
import yaml
import argparse
from pathlib import Path
from typing import List, Dict, Any
from collections import defaultdict


def replace_branch_placeholder(obj: Any, branch_name: str) -> Any:
    """
    Recursively replace BRANCH_PLACEHOLDER with the actual branch name in any data structure.

    Args:
        obj: The object to process (dict, list, str, or other)
        branch_name: The branch name to replace BRANCH_PLACEHOLDER with

    Returns:
        The object with all BRANCH_PLACEHOLDER occurrences replaced
    """
    if isinstance(obj, dict):
        return {k: replace_branch_placeholder(v, branch_name) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [replace_branch_placeholder(item, branch_name) for item in obj]
    elif isinstance(obj, str):
        return obj.replace('BRANCH_PLACEHOLDER', branch_name)
    else:
        return obj


def organize_by_levels(config_items: List[Dict[str, Any]], base_image_tag: str = None) -> List[List[Dict[str, Any]]]:
    """
    Organize configuration items into levels based on dependency depth.

    Args:
        config_items: List of configuration dictionaries from the YAML
        base_image_tag: Optional tag to append to base_image (e.g., "nightly", "v1.0")

    Returns:
        List of lists, where each inner list contains jobs at that dependency level
    """
    levels = defaultdict(list)

    def process_job(job: Dict[str, Any], level: int, parent_image: str = None):
        """Recursively process a job and its dependencies."""
        # Create a copy of the job without dependent_jobs for the output
        job_copy = {k: v for k, v in job.items() if k != 'dependent_jobs'}

        # Add base_image field for dependent jobs
        if parent_image:
            parent_image = parent_image.replace("/", "_")
            if base_image_tag:
                job_copy['base_image'] = f"{parent_image}--{base_image_tag}"
            else:
                job_copy['base_image'] = parent_image

        levels[level].append(job_copy)

        # Process dependent jobs at the next level, passing this job's image as base_image
        if 'dependent_jobs' in job:
            current_image = job.get('image')
            for dependent_job in job['dependent_jobs']:
                process_job(dependent_job, level + 1, current_image)

    # Process all top-level jobs
    for job in config_items:
        process_job(job, 0)

    # Convert defaultdict to sorted list of lists
    max_level = max(levels.keys()) if levels else 0
    return [levels[i] for i in range(max_level + 1)]


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description='Parse nightly matrix config YAML and organize jobs by dependency levels.'
    )
    parser.add_argument('yaml_file', help='Path to the YAML configuration file')
    parser.add_argument('output_dir', nargs='?', help='Optional output directory for JSON files')
    parser.add_argument('-t', '--tag', help='Tag to append to base_image (e.g., "nightly", "v1.0")')
    parser.add_argument('-b', '--branch', help='Branch name to replace BRANCH_PLACEHOLDER with')

    args = parser.parse_args()

    try:
        # Read and parse the YAML file
        with open(args.yaml_file, 'r') as f:
            data = yaml.safe_load(f)

        if 'config' not in data:
            print("Error: YAML file must contain a 'config' key", file=sys.stderr)
            sys.exit(1)

        # Replace BRANCH_PLACEHOLDER if branch is specified
        if args.branch:
            data = replace_branch_placeholder(data, args.branch)

        # Organize jobs by dependency levels
        levels = organize_by_levels(data['config'], args.tag)

        # Print the results summary
        print(f"Found {len(levels)} dependency levels:\n")

        for level_idx, jobs in enumerate(levels):
            print(f"Level {level_idx} ({len(jobs)} jobs):")
            for job in jobs:
                base = f" (base: {job['base_image']})" if 'base_image' in job else ""
                print(f"  - {job.get('repo', 'unknown')} -> {job.get('image', 'unknown')}{base}")
            print()

        # Write each level to a separate JSON file if output directory is specified
        if args.output_dir:
            output_path = Path(args.output_dir)
            output_path.mkdir(parents=True, exist_ok=True)

            for level_idx, jobs in enumerate(levels):
                output_file = output_path / f"level_{level_idx}.json"
                with open(output_file, 'w') as f:
                    output = {"image":jobs, "os": [{"arch": "arm64", "runner": "ubuntu-24.04-arm"},{"arch": "amd64", "runner": "ubuntu-latest"}]}
                    json.dump(output, f, indent=2)
                print(f"Wrote {len(jobs)} jobs to {output_file}")

            # Also write all levels combined
            all_levels_file = output_path / "all_levels.json"
            with open(all_levels_file, 'w') as f:
                json.dump(levels, f, indent=2)
            print(f"\nWrote all levels to {all_levels_file}")
        else:
            # Output all levels as JSON to stdout
            print("\nJSON Output:")
            print(json.dumps(levels, indent=2))

    except FileNotFoundError:
        print(f"Error: File '{args.yaml_file}' not found", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error parsing YAML: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
