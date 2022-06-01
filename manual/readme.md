# Maya

Maya was developed by the [Coordination Centre for Scientific University Collections in Germany](https://wissenschaftliche-sammlungen.de/en) at [Humboldt-Universität zu Berlin](https://www.hu-berlin.de/en).

## Documentation

### Generate the Documentation

To generate the documentation via [yard](http://yardoc.org) run `yard doc`. The options for this command are specified in the .yardopts file. The static doc files are written to public/docs.

## Usage

A quickguide for beginners can be found {file:quickguide.md here}.

### API

Our software has a JSON search api, which is documented {file:JSON_Discover_API.md here}.

## Setup

### Requirements

#### Ruby

We recommend [rvm](https://rvm.io) (the Ruby Version Manager) to install ruby.

#### Database

We use MySQL 5.7. Use your favourite method to install.

Other database adapters are available for ruby and should work with our software, although changes in the code may be necessary for getting them to work. 

##### Mysql Optimisation

The `setup` folder contains an example mysql config file and an example cron.d file for regular optimisation of the mysql database. 
Make copies of the example files `cp setup/maya-mysql.example.cnf setup/maya-mysql.cnf` and `cp setup/maya-mysql-optimisation.example.cron.d setup/maya-mysql-optimisation.cron.d`.
Fill in the settings in both files and link or copy *maya-mysql-optimisation.cron.d* in your */etc/cron.d* directory.

Our *cron.d* file looks like this `30 04 * * 0 maya mysql --defaults-file=/home/maya/maya-mysql.cnf < /var/www/maya/bin/maya-mysql-optimization.sql >> /var/www/maya/log/maya-mysql-optimization.log` where *maya* is our unix user.

#### Elasticsearch and Plugins

Elasticsarch 5.6 is required.

After installing it with your preferred method, use Elasticsearch's plugin manager to install the *Analysis ICU* plugin: `bin/elasticsearch-plugin install analysis-icu`.

#### Highchart

For the charts in the statistics module ("Kennzahlen") the javascript library Highchart.js is required.

[Get it here](https://www.highcharts.com) and place `highchart.js` in the folder `vendor/assets/javascripts`. Then add `//= require highcharts` in line 34 in `application.js`.

### Config Files

**config.yml** 
In this file, IMAP settings are stored so the application can send e-mails. Make a copy of the template file `cp config/config.yml.example config/config.yml` and fill in your IMAP server data.

**database.yml**
Make a copy of the template file `cp config/database.yml.example config/database.yml` and set adapter, host, port, login to connect with your database server.

**elasticsearch.yml**
Make a copy of the template file `cp config/elasticsearch.yml.example config/elasticsearch.yml` and set host, port etc. of your Elasticsearch node.

**secret_token.rb**

Make a copy of the template file `cp config/secret_token.rb.example config/secret_token.rb`.
Use `rake secret` to generate a secret token and insert it in `config/secret_token.rb`

### Required Gems

Run `bundle install` to install the gems listed in the Gemfile.

## Load Database Schema
Initialize database with `rails db:create db:schema:load`.

### Create an User
To create an initial default admin user on the command line execute the rails task `rails user:create_admin`.


## Index

The elasticsearch index is initially created from the rails console (invoke via `rails c`) by `Indexer.recreate_index!`. While running, the application automatically updates the index after changes using the information from the *revisions* database table.

## Kennzahlen

The Kennzahlen are created by invoking `WinstonGenerator.run!` in the rails console.

## Deploy to production

We use Phusion's Passenger plugin for Apache2. There should be no problems using the standalone Passenger, another ruby server or Passenger + Nginx.

Use your favourite way to install Apache2. 
To install Passenger in the next step, we recommend [Passenger's instalation guide](https://www.phusionpassenger.com/library/walkthroughs/deploy/ruby/ownserver/apache/oss/bionic/install_passenger.html). 

We strongly recommend to enforce HTTPS e.g. using a certificate from Let's Encrypt.

### Assets

After changing assets (images, javascript files, css files), you must run `rails assets:precompile` in production mode, so the assets can be served.

## Development

Use `rails s` or `rails server` to start WEBrick as a development web server.
