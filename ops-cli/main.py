import argparse
import os
import sys
from commands.create_service import create_service_command

def main():
    parser = argparse.ArgumentParser(description="CryptoLab Platform CLI")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # create-service command
    create_parser = subparsers.add_parser("create-service", help="Scaffold a new microservice")
    create_parser.add_argument("--name", required=True, help="Name of the service (e.g., btc-collector)")
    create_parser.add_argument("--coin", required=True, help="Cryptocurrency symbol (e.g., BTC, ETH)")
    create_parser.add_argument("--type", choices=["collector", "ingestor"], default="collector", help="Service type")

    args = parser.parse_args()

    if args.command == "create-service":
        create_service_command(args.name, args.coin, args.type)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
