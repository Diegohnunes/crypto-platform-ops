import sys
from commands.create_service import create_service_command
from commands.rm_service import rm_service_command

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python ops-cli/main.py create-service <name> <coin> <type>")
        print("  python ops-cli/main.py rm-service <name> <coin> <type>")
        print("\nExamples:")
        print("  python ops-cli/main.py create-service eth-collector eth collector")
        print("  python ops-cli/main.py rm-service eth-collector eth collector")
        sys.exit(1)

    command = sys.argv[1]

    if command == "create-service":
        if len(sys.argv) != 5:
            print("Usage: python ops-cli/main.py create-service <name> <coin> <type>")
            print("Example: python ops-cli/main.py create-service eth-collector eth collector")
            sys.exit(1)
        
        name = sys.argv[2]
        coin = sys.argv[3]
        service_type = sys.argv[4]
        
        create_service_command(name, coin, service_type)
    
    elif command == "rm-service":
        if len(sys.argv) != 5:
            print("Usage: python ops-cli/main.py rm-service <name> <coin> <type>")
            print("Example: python ops-cli/main.py rm-service eth-collector eth collector")
            sys.exit(1)
        
        name = sys.argv[2]
        coin = sys.argv[3]
        service_type = sys.argv[4]
        
        rm_service_command(name, coin, service_type)
    
    else:
        print(f"Unknown command: {command}")
        print("Available commands: create-service, rm-service")
        sys.exit(1)

if __name__ == "__main__":
    main()
