#!/bin/bash

required_env_vars=(
    "PORT_APP"
    "REDIS_PASSWORD"
    "MYSQL_HOST"
    "MYSQL_ROOT_PASSWORD"
    "MYSQL_USER"
    "MYSQL_PASSWORD"
    "MYSQL_DATABASE"
    "ELASTIC_HOST"
    "CONNECTION_URL"
    "COOKIE_DOMAIN"
)

declare -A default_values
default_values=(
    ["PORT_APP"]="8080"
    ["REDIS_PASSWORD"]="default_redis_password"
    ["MYSQL_ROOT_PASSWORD"]="123"
    ["MYSQL_USER"]="root"
    ["MYSQL_PASSWORD"]="123"
    ["MYSQL_DATABASE"]="magento"
)

# Function to check and populate the .env file
check_env_file() {
    local env_file=".env"

    echo "Checking for .env file in the current directory..."
    sleep 1
    echo
    sleep 1

    # Si le fichier .env n'existe pas, on le crée
    if [ ! -f "$env_file" ]; then
        echo ".env file not found. Creating a new one..."
        touch "$env_file"
    else
        echo ".env file found."
    fi

    echo

    # Charger les variables d'environnement du fichier .env
    if [ -f ".env" ]; then
        source .env
        echo ".env file loaded successfully."
    else
        echo "Error: .env file not found."
        exit 1
    fi

    # Vérification que la variable SERVICE_NAME est définie
    if [ -z "$SERVICE_NAME" ]; then
        echo "SERVICE_NAME is not defined in the .env file."
        default_value="magento"
        read -p "Enter your project name (default: $default_value): " service_name
        # Si l'utilisateur n'entre rien, utiliser la valeur par défaut
        SERVICE_NAME="${service_name:-$default_value}"
        echo "SERVICE_NAME=${SERVICE_NAME}" >> "$env_file"
    else
        echo "SERVICE_NAME is: $SERVICE_NAME"
    fi

    if [ -z "$SERVICE_NAME" ]; then
        echo "The project name is mandatory, please run the script again"
        exit 1
    fi

    # Lire les variables existantes dans .env
    declare -A existing_vars
    while IFS="=" read -r key value; do
        if [[ ! -z "$key" && ! -z "$value" ]]; then
            existing_vars[$key]="$value"
        fi
    done < <(grep -E '^[A-Z_]+=.*$' "$env_file")

    # Vérification des variables manquantes
    local missing_vars=0
    for key in "${required_env_vars[@]}"; do
        if [ -z "${existing_vars[$key]}" ]; then
            missing_vars=$((missing_vars + 1))
            while true; do
                # Si la variable est MYSQL_HOST, utiliser le SERVICE_NAME pour déterminer la valeur par défaut
                if [ "$key" == "MYSQL_HOST" ]; then
                    default_value="${SERVICE_NAME}_mysql"
                elif [ "$key" == "ELASTIC_HOST" ]; then
                    default_value="${SERVICE_NAME}_elasticsearch"
                elif [ "$key" == "CONNECTION_URL" ]; then
                    default_value="http://${SERVICE_NAME}.local/"
                elif [ "$key" == "COOKIE_DOMAIN" ]; then
                    default_value="${SERVICE_NAME}.local"
                else
                    default_value="${default_values[$key]}"
                fi

                # Demander une valeur à l'utilisateur, avec une valeur par défaut
                read -p "Enter value for $key (default: $default_value): " user_value
                # Si l'utilisateur n'entre rien, utiliser la valeur par défaut
                user_value="${user_value:-$default_value}"

                # Éviter d'ajouter une valeur vide
                if [ -n "$user_value" ]; then
                    echo "$key=$user_value" >> "$env_file"
                    break
                else
                    echo "The value for $key cannot be empty. Please try again."
                fi
            done
        fi
    done

    if [ $missing_vars -eq 0 ]; then
        echo "All required variables are already present in the .env file."
    else
        echo "$missing_vars variables were added to the .env file."
    fi
    echo
    sleep 1

    echo "Final .env file:"
    cat "$env_file"
    sleep 1
    echo
}

display_initial_menu() {
    echo "Please select the type of installation:"
    echo "1) Install from an existing project"
    echo "2) Create a new Magento project"
    echo "3) Exit"
}

# Function to handle user choice for the initial menu
handle_initial_choice() {
    case $1 in
        1)
            echo "You selected: Install from an existing project."
            setup_existing_project
            ;;
        2)
            echo "You selected: Create a new Magento project."
            setup_new_project
            ;;
        3)
            echo "Exiting. Thank you!"
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
}

get_absolute_path() {
    while true; do
        echo "Please provide the path to your project directory ($(pwd)):"
        read -r project_path

        # Use current directory if input is empty
        project_path="${project_path:-$(pwd)}"

        # Check if the path is absolute
        if [[ "$project_path" == /* ]]; then
            echo "Using Magento project directory: $project_path"
            return 0
        else
            echo "Error: The path must be absolute (e.g., /var/www/magento). Please try again."
        fi
    done
}

check_dependencies() {
    echo "Checking dependencies..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed. Please install Docker before proceeding."
        exit 1
    else
        echo "Docker is installed."
    fi

    # Check if Curl is installed
    if ! command -v curl &> /dev/null; then
        echo "Error: Curl is not installed. Please install Curl before proceeding."
        exit 1
    else
        echo "Curl is installed."
    fi

    echo "All required dependencies are installed."
}

check_or_download_compose_file()
{
    if [ ! -f "$project_path/magefine-compose.yml" ]; then
        echo "magefine-compose.yml not found. Downloading..."

        # Use curl to download the file (using a placeholder URL)
        curl -o "$project_path/magefine-compose.yml" "https://raw.githubusercontent.com/Magefine/MageStart/refs/heads/master/docker-compose.yml"

        # Check if the download was successful
        if [ -f "$project_path/magefine-compose.yml" ]; then
            echo "magefine-compose.yml downloaded successfully."
        else
            echo "Failed to download magefine-compose.yml. Please check your internet connection and try again."
            exit 1
        fi
    else
        echo "magefine-compose.yml already exists in the project."
    fi
    echo
}

check_or_download_dockerfile()
{
    if [ ! -f "$project_path/magefine.Dockerfile" ]; then
        echo "magefine.Dockerfile not found. Downloading..."

        # Use curl to download the file (using a placeholder URL)
        curl -o "$project_path/magefine.Dockerfile" "https://raw.githubusercontent.com/Magefine/MageStart/refs/heads/master/Dockerfile"

        # Check if the download was successful
        if [ -f "$project_path/magefine.Dockerfile" ]; then
            echo "magefine.Dockerfile downloaded successfully."
        else
            echo "Failed to download magefine.Dockerfile. Please check your internet connection and try again."
            exit 1
        fi
    else
        echo "magefine.Dockerfile already exists in the project."
    fi
    echo
}

docker_build()
{
    echo "Building docker images..."
    docker compose -f magefine-compose.yml --env-file .env build
    echo "Build finished"
    echo
}

docker_up()
{
    echo "Running docker containers"
    docker compose -f magefine-compose.yml --env-file .env up -d
    sleep 3
    echo "Containers are running"
    echo
}

bin_magento_setup_install()
{
    rm -f app/etc/env.php

    source ./.env

    container_name="${SERVICE_NAME}_app"

    docker exec -it ${container_name} bin/magento setup:install \
    --db-host=${MYSQL_HOST} \
    --db-name=${MYSQL_DATABASE} \
    --db-user=${MYSQL_USER} \
    --db-password=${MYSQL_PASSWORD} \
    --admin-firstname=admin \
    --admin-lastname=admin \
    --admin-email=admin@${COOKIE_DOMAIN} \
    --admin-user=admin \
    --admin-password=admin123 \
    --language=en_US \
    --currency=USD \
    --timezone=America/Chicago \
    --use-rewrites=1 \
    --search-engine=elasticsearch7 \
    --elasticsearch-host=${SERVICE_NAME}_elasticsearch \
    --elasticsearch-port=9200 \
    --backend-frontname=admin
    echo "Database initialized successfully."
}

install_sample_data()
{
    source ./.env

    container_name="${SERVICE_NAME}_app"

    echo "Do you want to install sample data ?"
    echo "1) Yes"
    echo "2) No"
    read -p "Your choice: " sample_data_yesno

    case $sample_data_yesno in
        1)
            echo "Installing sample data"

            docker exec -it ${container_name} bin/magento sampledata:deploy
            docker exec -it ${container_name} bin/magento setup:upgrade
            ;;
    esac

    echo
}

initialize_database() {
    echo "Do you want to initialize the database or restore from a dump?"
    echo "1) Initialize new database"
    echo "2) Restore from existing dump"
    read -p "Your choice: " db_choice

    source ./.env

    container_name="${SERVICE_NAME}_app"

    case $db_choice in
        1)
            echo "Initializing new database..."

            bin_magento_setup_install

            install_sample_data

            ;;
        2)
            echo "Restoring from existing dump..."
            read -p "Enter the path to your SQL dump file: " dump_file

            # Check if the dump file exists
            if [ ! -f "$dump_file" ]; then
                echo "Error: Dump file not found. Please provide a valid path."
                exit 1
            fi

            # Command to restore from dump (adjust as needed)
            docker exec -i ${MYSQL_HOST} mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < "$dump_file"
            echo "Database restored successfully from the dump."
            ;;
        *)
            echo "Invalid option. Exiting..."
            exit 1
            ;;
    esac
}

update_hosts_file() {
    source ./.env

    local hosts_file="/etc/hosts"

    # Vérifie si le domaine est déjà présent dans /etc/hosts
    if grep -q "$COOKIE_DOMAIN" "$hosts_file"; then
        echo "The domain '$COOKIE_DOMAIN' is already in $hosts_file."
    else
        echo "Adding '$COOKIE_DOMAIN' to $hosts_file..."

        # Ajoute le domaine à la boucle locale (127.0.0.1)
        echo "127.0.0.1 $COOKIE_DOMAIN" | sudo tee -a "$hosts_file" > /dev/null

        # Confirmation
        if grep -q "$COOKIE_DOMAIN" "$hosts_file"; then
            echo "Successfully added '$COOKIE_DOMAIN' to $hosts_file."
        else
            echo "Failed to add '$COOKIE_DOMAIN' to your host file. Please check your permissions."
        fi
    fi
}

deploy_dev()
{
    source ./.env

    container_name="${SERVICE_NAME}_app"

    docker exec -i ${container_name} bin/magento deploy:mode:set developer
    docker exec -i ${container_name} chown -R magefine:magefine .

    echo "Setup complete access ${COOKIE_DOMAIN}:${PORT_APP} in your web browser"
}

# Function to set up an existing project
setup_existing_project() {
    # Example check to ensure the directory exists
    if [ ! -d "$project_path" ]; then
        echo "Error: Directory does not exist. Please provide a valid path."
        exit 1
    fi

    if [ -d "$project_path" ]; then
        echo "Project found at $project_path."
        echo
        sleep 1

        check_or_download_compose_file

        check_or_download_dockerfile

        docker_build

        docker_up

        source ./.env

        container_name="${SERVICE_NAME}_app"

        echo "Installing composer packages..."
        rm -rf vendor/*
        docker exec -it ${container_name} composer install
        echo
        sleep 1

        initialize_database

        echo "Updating host file..."
        update_hosts_file
        echo "Done"
        sleep 1
        echo

        deploy_dev
    else
        echo "Directory not found: $project_path. Returning to the main menu."
    fi
}

# Function to set up a new Magento project
setup_new_project() {
    echo "Starting a new Magento project installation."
    echo "Enter the version of Magento to install (e.g., 2.4.7-p3) leave blank to get the latest:"
    read -p "Magento version: " magento_version

    magento_default_version="2.4.7-p3"

    magento_version="${magento_version:-$(magento_default_version)}"

    check_or_download_compose_file

    check_or_download_dockerfile

    docker_build

    docker_up

    source ./.env

    container_name="${SERVICE_NAME}_app"

    echo "Installing Magento $magento_version..."
    docker exec -it ${container_name} composer create-project --prefer-source --repository=https://repo.magento.com/ magento/project-community-edition="$magento_version" "tmp"

    sudo mv -i tmp/{.,}* .

    echo "Setting correct file permissions..."
    sudo chmod -R 777 "./var" "./generated" "./pub/static" "./pub/media"

    sudo rm -rf ./tmp

    sleep 1

    initialize_database

    echo
    sleep 1

    echo "Updating host file..."
    update_hosts_file
    echo "Done"
    sleep 1
    echo

    deploy_dev
}

echo "Welcome to the Magento Installation Script!"
sleep 1
echo
sleep 1
echo

check_dependencies
echo
sleep 1

get_absolute_path
echo

cd $project_path

check_env_file
echo "Check OK"
sleep 1
echo
sleep 1


display_initial_menu
read -p "Your choice: " user_choice
echo
handle_initial_choice $user_choice
echo # Add a blank line for better readability
