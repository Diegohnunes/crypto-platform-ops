import argparse
import os
import sys
from commands.create_service import create_service_command
from commands.rm_service import rm_service_command

def main():
        create_service_command(args.name, args.coin, args.type)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
