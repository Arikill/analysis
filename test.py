from libs.readers import XLReader
from libs.systems import Analyzer
from libs.sysops import *
import numpy as np
import matplotlib.pyplot as plt
import argparse
import logging
import os
from pathlib import Path

def init_logging():
    current_file = os.path.splitext(os.path.basename(__file__))[0]
    logging.basicConfig(filename=current_file+".log", level=logging.DEBUG, format="%(asctime)s - %(levelname)s - %(message)s")

def load_configurations():
    configurations_json: Path = "./settings/configurations.json"
    return Configurations(configurations_json)

def main():
    configs = load_configurations()
    parser = argparse.ArgumentParser(description="Passing named arguments to analyzer")
    parser.add_argument("--show_configs", "-sc", action="store_true", help="show configurations")
    parser.add_argument("--list_inputs", "-li", action="store_true", help="list files from the input directory")
    parser.add_argument("--list_skips", "-ls", action="store_true", help="list files that are specified to be skipped in configurations")
    parser.add_argument("--list_files", "-la", action="store_true", help="list files that will be analyzed as per current configuraitons")
    parser.add_argument("--set_inputdir", "-si", type=Path, default = None, help="set input directory in configurations")
    parser.add_argument("--set_outputdir", "-so", type=Path, default = None, help="set output directory in configurations")
    parser.add_argument("--run", "-r", action="store_true", help="Run all the files in a dictory and put the results in outputs")
    parser.add_argument("--run-file", "-rf", type=Path, default = None, help="run a single file")
    args = parser.parse_args()
    if args.show_configs:
        print(configs.settings)
    if args.list_inputs:
        print(configs.get_input_files())
    if args.list_skips:
        print(configs.get_files_to_skip())
    if args.list_files:
        print(configs.get_files_to_analyze())
    if args.set_inputdir is not None:
        configs.set_input_directory(args.set_inputdir)
        print(configs.settings)
    if args.set_outputdir is not None:
        configs.set_output_directory(args.set_outputdir)
        print(configs.settings)
    if args.run:
        inputdir = configs.get_input_directory()
        inputfiles = configs.get_files_to_analyze()
        files = [inputdir / filename for filename in inputfiles]
        analyzer = Analyzer(files, configs.get_output_directory(), configs.get_filters())
        analyzer.run()
    if args.run_file is not None:
        inputdir = configs.get_input_directory()
        filepath = inputdir / args.run_file
        if filepath.exists():
            analyzer = Analyzer([filepath], configs.get_output_directory())
            analyzer.run(configs.get_optimization()["level"])
        else:
            BufferError(f"{filepath} doesn't exist!")

if __name__ == "__main__":
    main()