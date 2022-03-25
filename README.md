# Hy-C

![Build](https://github.com/UNC-Libraries/hy-c/workflows/Build/badge.svg?branch=main)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)
[![Maintainability](https://api.codeclimate.com/v1/badges/5114a1aec550de0ce672/maintainability)](https://codeclimate.com/github/UNC-Libraries/hy-c/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/5114a1aec550de0ce672/test_coverage)](https://codeclimate.com/github/UNC-Libraries/hy-c/test_coverage)

#### Hyrax based system underlying the Carolina Digital Repository

* Currently using Hyrax version 2.9.5
* Currently in production
* Hosts institutional repository content at UNC Chapel Hill

#### Customizations

* Automatically assign AdminSet based on work type
* Custom workflows:
    * New withdrawn state for works
    * Honors thesis workflow automatically assigns departmental group as reviewer for deposited works
* Updated deposit/edit form with combined files and metadata tabs
* Import scripts for new ProQuest deposits
* Merges old and new analytics data from Google Analytics

##### Sage ingest rake task
* From the command line, run
```bash
bundle exec rake sage:ingest[PATH_TO_CONFIG]
```
 e.g.
```bash
bundle exec rake sage:ingest[/hyrax/spec/fixtures/sage/sage_config.yml]
```
* See [example config file](spec/fixtures/sage/sage_config.yml).
* The beginning and ending of the rake task will be output to the console, the remaining events will be logged to the sage ingest log (in the same directory as the Rails log).

#### Development on Docker
* Pre-requisites:
  * Docker installed locally
  * (optional) If you use Atom, get the Dockerfile specific grammar (may need to restart Atom to see effect) `apm install language-docker`
* Ensure you have the needed environment variables in `config/local_env.yml`. Either get a copy of this file from a colleague, or copy the sample file and fill in the appropriate values
```bash
cp config/local_env_sample.yml config/local_env.yml
  ```
- Either pull (faster) or build the application docker image
```bash
docker compose pull
OR
docker compose build
```
- Bring up the application and its dependencies
```bash
docker compose up
```
- Copy .bashrc into web container
```bash
docker cp ./docker/.bashrc hy-c-web-1:/root/.bashrc
```
- Go into a bash shell inside the running web container
```bash
docker compose exec web bash
```
- If you don't want to have to type `bundle exec` in front of each command, you can use the following command:

*NOTE: You will not be able to run `bundle install` in this shell, since you would effectively be trying to run `bundle exec bundle install`, which doesn't work.*
  ```bash
  docker compose exec bundle exec web bash
  ```
- You can edit the code in your editor, as usual, and the changes will be reflected inside the docker container.
- You should be able to see the application at http://localhost:3000/
#### Testing
##### RSpec Testing
* Creating Solr fixture objects (see `spec/support/oai_sample_solr_documents.rb` )
  * Run the test_setup rake task in order to get all the fixtures in the development environment
  ```
  bundle exec rake test_setup RAILS_ENV=development
  ```
  * Search in your development environment front end to find the ID for the object you want to update (if using the UNC-CH VM this will be at localhost:4040, if you are running it locally on the default rails server, it will be at localhost:3000)
  * Go into a rails console to retrieve objects
  ```
  bundle exec rails console RAILS_ENV=development
  ```
  * On the rails console, find the object.
    * If the url is https://localhost:4040/concern/articles/5x21tf41f?locale=en then the model is `Article` and the id is `5x21tf41f`.
    Example:
    ```ruby
    work = Article.find("5x21tf41f")
    work.to_solr.deep_symbolize_keys!
    ```
    ```ruby
    work = YourModel.find("YourIdAsAString")
    work.to_solr.deep_symbolize_keys!
    ```
    * Copy the output of this to the sample_solr_documents file. Add a unique `:timestamp` value to the hash (e.g. `:timestamp => "2021-11-23T16:05:33.033Z"`) so that the `spec/requests/oai_pmh_endpoint_spec.rb` tests to continue to pass.

#### Debugging Capybara feature and javascript tests
* Save a screenshot
  * Put `page.save_screenshot('screenshot.png')` on the line before the failing test (you can use a different name for the file if that's helpful)
  * The screenshot will be saved to `tmp/capybara`.
  * See https://github.com/teamcapybara/capybara#debugging for more info


##### Code Linter - Rubocop
  * Helpful Rubocop documentation - https://docs.rubocop.org/rubocop/usage/basic_usage.html
  * Run Rubocop on entire project
  ```bash
  bundle exec rubocop
  ```
  * Run Rubocop on a single file
  ```bash
  bundle exec rubocop relative/path/to/file.ext
  ```
  * If Rubocop flags something that you do not think should be flagged, either:
    * Wrap it with `#rubocop:disable` / `#rubocop:enable` comments:
  ```ruby
  #rubocop:disable RuleFamily/RuleName
  def my_method
    blah blah blah
  end
  #rubocop:enable RuleFamily/RuleName
  ```
  e.g.
  ```ruby
  #rubocop:disable Naming/PredicateName
  def is_a_bad_method_name
    blah blah blah
  end
  #rubocop:enable Naming/PredicateName
  ```
    * Or add it to the `.rubocop.yml` file, excluding either an individual file, or changing the configuration for a given rule.

#### Contact Information
* Email: cdr@unc.edu
