# phalconver

phalconver.sh is a helper script for switching between different PHP and [Phalcon](https://phalconphp.com) versions installed on your system. It can switch both CLI PHP , and PHP loaded into your Apache2 web server. It has been tested on Linux Mint 17.1 Rebecca, but should work on Ubuntu and Debian as well.

## Installation

```bash
sudo cp phalconver.sh /usr/local/bin/phalconver
```

### Install Apache2 + PHP

It is assumed, that you have both Apache2 and PHP installed on your system in standard locations (i.e. you installed them using apt). 

```bash
sudo apt-get install apache2
```

It is OK to install multiple PHP versions. For example you may install PHP 5.6:

```bash
sudo apt-get install php5.6 php5.6-common php5.6-cli php5.6-dev libapache2-mod-php5.6
```

and you may also install PHP 7.0:

```bash
sudo add-apt-repository ppa:ondrej/php
sudo apt-get update
sudo apt-get install php7.0 php7.0-common php7.0-cli php7.0-dev libapache2-mod-php7.0
```

### Install Phalcon

Phalcon installation instructions are [here](https://phalconphp.com/en/download/linux). Install multiple Phalcon versions one by one. After each installation go to the appropriate PHP extension directory in */usr/lib/php* where phalcon.so has just been installed. Rename *phalcon.so* to include Phalcon version number.

```bash
sudo apt-get install php5-phalcon
cd /usr/lib/php/20131226/
sudo mv phalcon.so phalcon.1.3.6.so
```

Install another Phalcon version and do the similar:

```bash
sudo apt-get install php7.0-phalcon
cd /usr/lib/php/20151012/
sudo mv phalcon.so phalcon.3.0.4.so
```

Each PHP version has different extension directory. They are all in */usr/lib/php*. Check [this page](https://support.zend.com/hc/en-us/articles/217058968-PHP-Versions-and-APIs), column PHP extension.

Setup symlinks to all installed phalcon modules.

```bash
cd /usr/lib/php/20131226/
sudo ln -s phalcon.1.3.6.so phalcon.so
```

You need to repeat this step for every PHP extension directory in which Phalcon is installed

Finally, configure your PHP to load Phalcon.

```bash
sudo phpenmod phalcon
sudo php5enmod phalcon
```

You may want to check that *all PHP versions* installed on your system have the Phalcon module activated. Go to */etc/php/X.Y/apache2/conf.d/* and */etc/php/X.Y/cli/conf.d/* and make sure that there is a symlink for phalcon.ini file.

## Usage

The syntax is

```bash
phalconver [OPTIONS] COMMAND [ARGUMENT]
```

Available commands:

* status
* list
* use
* help

### status

Displays the currently active PHP version for both CLI and Apache2.

```bash
phalconver status
```

### list

Displays installed PHP and Phalcon versions on your system.

```bash
phalconver list
```

### use

Switches to the given PHP version. Has option to switch the CLI or Apache version only. Additionally, it has an option for switching currently active Phalcon version.

```bash
sudo phalconver use php7.0
```
This will switch PHP version to 7.0 for both CLI and Apache.


```bash
sudo phalconver -c use php5.6
```
This will switch PHP version to 7.0 for CLI only.


```bash
sudo phalconver -a use php7.1
```
This will switch PHP version to 7.1 for Apache only.


```bash
sudo phalconver -p 1.3.6 use php5.6
```
This will switch Phalcon version to 1.3.6 for PHP 5.6, and switch PHP to 5.6 for both Apache and CLI.

