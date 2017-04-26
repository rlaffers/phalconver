#!/bin/bash - 
#===============================================================================
#
#          FILE: phpversion.sh
# 
#         USAGE: ./phpversion.sh [OPTIONS] COMMAND [ARGUMENT]
# 
#   DESCRIPTION: Helper script for switching between multiple PHP versions with Phalcon installed on your machine.
# 
#       OPTIONS: -a
#                -c
#                -p
#  REQUIREMENTS: php, a2query, a2enmod, a2dismod
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Richard Laffers
#  ORGANIZATION: 
#       CREATED: 03/22/2017 16:15
#      REVISION:  ---
#===============================================================================

usage() {
cat << EOF
Usage: $0 [OPTIONS] COMMAND [ARGUMENT]

This program can switch PHP and Phalcon versions installed on your system for you.

COMMANDS
    use
    list
    help
    status

ARGUMENT
    Only relevant for the "use" command. Must specify version of PHP you wish to switch to.
    Valid formats:  5.6
                    php5.6

OPTIONS:
   -c   Switch only the CLI PHP version. Mutually exclusive with -a.
   -a   Switch only the Apache PHP version. Mutually exclusive with -c.
   -p   Switch Phalcon version for both CLI and Apache. Different PHP versions may have different Phalcon versions available. Use
        the list command to check which Phalcon versions are installed on your system.

EXAMPLES:
    phpversion.sh status
    phpversion.sh list
    phpversion.sh use php7.0
    phpversion.sh -c use php7.1
    phpversion.sh -p 1.3.6 use php5.6
EOF
}


# Switch PHP to the designated version. Can pass "5.6" or "php5.6" as the first argument.
switch_php() {
    local target_version="${1/php/}"
    info "Switching PHP to version $target_version"
    if [[ "$CLI_ONLY" != 1 ]]; then
        local apache_versions=$(get_apache_php_versions)
        if [[ "$apache_versions" != *"php$target_version"* ]]; then
            error "Version $target_version is not available pre Apache"
            exit 1
        fi
    fi
    if [[ "$APACHE_ONLY" != 1 ]]; then
        local cli_versions=$(get_cli_php_versions)
        if [[ "$cli_versions" != *"php$target_version"* ]]; then
            error "Version $target_version is not available pre CLI"
            exit 1
        fi
    fi

    # lets switch the CLI PHP version
    if [[ "$APACHE_ONLY" != 1 ]]; then
        local current_cli_version=$(get_current_cli_version)

        if [[ "$current_cli_version" == "$target_version" ]]; then
            info "Current PHP CLI version is already set to $target_version. No need to switch it."
        else
            rm $ALTERNATIVES_DIR/php
            ln -s $PHP_BIN_DIR/php$target_version $ALTERNATIVES_DIR/php
            rm $ALTERNATIVES_DIR/phpize
            ln -s $PHP_BIN_DIR/phpize$target_version $ALTERNATIVES_DIR/phpize
            rm $ALTERNATIVES_DIR/php-config
            ln -s $PHP_BIN_DIR/php-config$target_version $ALTERNATIVES_DIR/php-config

            info "CLI PHP switched to version $target_version"
        fi
    fi

    # lets switch the Apache PHP version
    if [[ "$CLI_ONLY" != 1 ]]; then
        local current_apache_version=$(get_current_apache_version)
        if [[ "$current_apache_version" == "$target_version" ]]; then
            info "Current PHP Apache version is already set to $target_version. No need to switch it."
        else
            a2dismod "php$current_apache_version"
            a2enmod "php$target_version"
            info "Switched to php$target_version for Apache. For changes to take place you need to run:"
            echo -e "\nservice apache2 reload"
        fi
    fi

}

# Switch current Phalcon version (change is applied to the given PHP version. Thus, the -a, -c options are meaningless here).
# expects 2 arguments (target Phalcon version, and PHP version for which Phalcon should be switched)
switch_phalcon() {
    # validate both arguments
    local target_phalcon_version=$1
    local target_php_version="${2/php/}"
    if [[ -z "$target_phalcon_version" ]]; then
        error "Missing first parameter (Phalcon version) in call to switch_phalcon() function"
    fi
    if [[ -z "$target_php_version" ]]; then
        error "Missing second parameter (PHP version) in call to switch_phalcon() function"
    fi
    info "Switching Phalcon to version $target_phalcon_version for PHP $target_php_version"

    case $target_php_version in
        "5.3" )
            php_api_dir=$PHP53_API_DIR
            ;;
        "5.4" )
            php_api_dir=$PHP54_API_DIR
            ;;
        "5.5" )
            php_api_dir=$PHP55_API_DIR
            ;;
        "5.6" )
            php_api_dir=$PHP56_API_DIR
            ;;
        "7.0" )
            php_api_dir=$PHP70_API_DIR
            ;;
        "7.1" )
            php_api_dir=$PHP71_API_DIR
            ;;
        * )
            error "Invalid PHP version: $target_php_version"
            exit 1
            ;;
    esac

    # check if target phalcon exists for given PHP
    if [[ !(-f "$php_api_dir/phalcon.$target_phalcon_version.so") ]]; then
        error "phalcon.$target_phalcon_version.so module does not exist in $php_api_dir"
        exit 1
    fi

    if [[ -L "$php_api_dir/phalcon.so" ]]; then
        rm $php_api_dir/phalcon.so
    fi
    ln -s $php_api_dir/phalcon.$target_phalcon_version.so $php_api_dir/phalcon.so

    info "Switched to Phalcon $target_phalcon_version To apply theis change to Apache you need to run:"
    echo -e "\nservice apache2 reload"
}

# Prints current PHP and Phalcon version for both CLI and Apache
print_status() {
    # current CLI versions
    local cli_phalcon_version=$(get_current_cli_phalcon_version)
    echo -e "CLI:\n    php$(get_current_cli_version)\n    Phalcon $cli_phalcon_version\n"

    # current Apache versions
    local apache_php_version=$(get_current_apache_version)
    local apache_phalcon_version=$(get_current_apache_phalcon_version)
    echo -e "Apache:\n    php$apache_php_version\n    Phalcon $apache_phalcon_version"
}

# Detects current PHP version for CLI
get_current_cli_version() {
    local cli_php_version=`php -v|grep cli|sed -n 's/PHP\s\([0-9]\.[0-9]\).*/\1/p'`
    echo $cli_php_version
}

# Detects current PHP version for Apache
get_current_apache_version() {
    local apache_php_version=`a2query -m|sed -n 's/^php\([0-9].[0-9]\).*/\1/p'`
    echo $apache_php_version
}

# Detects current Phalcon version for CLI
get_current_cli_phalcon_version() {
    local php_bin=$ALTERNATIVES_DIR/php
    if [[ !(-x "$php_bin") ]]; then
        error "File $php_bin does not exist or is not executable!"
        return 1
    fi
    local cli_phalcon_version=`$php_bin -i|grep "Phalcon Version"|sed -n 's/.*=>\s\(.*\)/\1/p'`
    if [[ -z $cli_phalcon_version ]]; then
        # Higher versions of PHP/Phalcon report in alternative format
        cli_phalcon_version=`php -i|sed -n '/Author => Phalcon/{n;p}'|sed -n 's/.* => \(.*\)/\1/p'`
    fi
    echo $cli_phalcon_version
}

# Detects the current Phalcon version for Apache. Considers the phalcon.so link inside the relevant phpapi directory.
get_current_apache_phalcon_version() {
    local apache_php_version=$(get_current_apache_version)
    local php_api_dir=""
    case $apache_php_version in
        "5.3" )
            php_api_dir=$PHP53_API_DIR
            ;;
        "5.4" )
            php_api_dir=$PHP54_API_DIR
            ;;
        "5.5" )
            php_api_dir=$PHP55_API_DIR
            ;;
        "5.6" )
            php_api_dir=$PHP56_API_DIR
            ;;
        "7.0" )
            php_api_dir=$PHP70_API_DIR
            ;;
        "7.1" )
            php_api_dir=$PHP71_API_DIR
            ;;
        * )
            error "Invalid current Apache PHP version: $apache_php_version"
            exit 1
            ;;
    esac

    if [[ !(-L $php_api_dir/phalcon.so) ]]; then
        error "Failed to detect Phalcon version because of missing symbolic link $php_api_dir/phalcon.so"
        exit 1
    fi
    local current_apache_phalcon_version=`readlink $php_api_dir/phalcon.so|sed -n 's/phalcon\.\(.*\)\.so/\1/p'`
    echo $current_apache_phalcon_version

}

# Returns PHP versions available for CLI
get_cli_php_versions() {
    local cli_php_versions=`find $PHP_BIN_DIR -name "php[0-9]*" -printf "%f\n"`
    echo -e $cli_php_versions
}

# Returns PHP versions available for Apache
get_apache_php_versions() {
    local apache_php_versions=`ls $APACHE_MOD_DIR|grep "php.*\.load"|sed -n 's/\(php.*\)\.load/    \1/p'`
    echo -e $apache_php_versions
}

# Prints all available PHP versions installed on your system
print_list() {
    # Available PHP CLI versions
    echo -e "PHP versions available on your system:\n\nCLI"
    echo -e "    $(get_cli_php_versions)\n"

    # Available PHP versions for Apache
    echo -e "Apache:"
    echo -e "    $(get_apache_php_versions)\n"

    # Available Phalcon versions
    echo "Phalcon versions:"
    if [[ -d "$PHP53_API_DIR" ]]; then
        echo -e "  (php5.3)"
        ls $PHP53_API_DIR/|grep phalcon|sed -n 's/phalcon\.\(.*\)\.so/    \1/p'
    fi

    if [[ -d "$PHP54_API_DIR" ]]; then
        echo -e "  (php5.4)"
        ls $PHP54_API_DIR/|grep phalcon|sed -n 's/phalcon\.\(.*\)\.so/    \1/p'
    fi

    if [[ -d "$PHP55_API_DIR" ]]; then
        echo -e "  (php5.5)"
        ls $PHP55_API_DIR/|grep phalcon|sed -n 's/phalcon\.\(.*\)\.so/    \1/p'
    fi

    if [[ -d "$PHP56_API_DIR" ]]; then
        echo -e "  (php5.6)"
        ls $PHP56_API_DIR/|grep phalcon|sed -n 's/phalcon\.\(.*\)\.so/    \1/p'
    fi

    if [[ -d "$PHP70_API_DIR" ]]; then
        echo -e "  (php7.0)"
        ls $PHP70_API_DIR/|grep phalcon|sed -n 's/phalcon\.\(.*\)\.so/    \1/p'
    fi

    if [[ -d "$PHP71_API_DIR" ]]; then
        echo -e "  (php7.1)"
        ls $PHP71_API_DIR/|grep phalcon|sed -n 's/phalcon\.\(.*\)\.so/    \1/p'
    fi

}

info() {
    echo -e "\e[01;36m[INFO]\e[00m  $1"
}	# ----------  end of function info  ----------

error() {
    echo -e "\e[01;31m[ERROR]\e[00m $1"
}	# ----------  end of function error ----------

warn() {
    echo -e "\e[01;33m[WARN]\e[00m  $1"
}	# ----------  end of function warn ----------

PHP_VERSION=""
PHALCON_VERSION=""
CLI_ONLY="0"
APACHE_ONLY="0"
ALTERNATIVES_DIR="/etc/alternatives"
PHP_BIN_DIR="/usr/bin"
APACHE_MOD_DIR="/etc/apache2/mods-available"
PHP53_API_DIR="/usr/lib/php/20090626"
PHP54_API_DIR="/usr/lib/php/20100525"
PHP55_API_DIR="/usr/lib/php/20121212"
PHP56_API_DIR="/usr/lib/php/20131226"
PHP70_API_DIR="/usr/lib/php/20151012"
PHP71_API_DIR="/usr/lib/php/20160303"

while getopts ":cap:" opt; do
    case "$opt" in
    c)  CLI_ONLY="1"
        ;;
    a)  APACHE_ONLY="1"
        ;;
    p)  PHALCON_VERSION=$OPTARG
        ;;
    esac
done

if [[ "$APACHE_ONLY" == "1" && "$CLI_ONLY" == "1" ]]; then
    error "Options -a, -c are mutually exclusive."
    exit 1
fi

LAST_ARG_IDX="$#"
PENULTIMATE_ARG_IDX=`expr $LAST_ARG_IDX - 1`

COMMAND=${!LAST_ARG_IDX}
# if this is not help, list, nor status command, the last item actually is not the command. Let us consider the penultimate item as the actual command.
if [[ "$COMMAND" != "list" && "$COMMAND" != "help" && "$COMMAND" != "status" ]]; then
    COMMAND=${!PENULTIMATE_ARG_IDX}
fi

case $COMMAND in
    use )
        if [[ ${UID} != 0 ]]; then
            error "You must run this script as root to switch PHP versions"
            exit 1
        fi
        PHP_VERSION=${!LAST_ARG_IDX}
        switch_php $PHP_VERSION
        if [[ "$PHALCON_VERSION" != "" ]]; then
            # switch Phalcon version for this PHP version
            switch_phalcon $PHALCON_VERSION $PHP_VERSION
        fi
        ;;
    list )
        print_list
        ;;
    status )
        print_status
        ;;
    help )
        usage
        exit 0
        ;;
    * )
        error "Bad command."
        usage
        exit 1
        ;;
esac
