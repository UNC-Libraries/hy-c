# Hy-C

![Build](https://github.com/UNC-Libraries/hy-c/workflows/Build/badge.svg?branch=main)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)

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
* The beginning and ending of the rake task will be output to the console, the remaining events will be logged to the rails log and tagged with "Sage ingest".

#### Testing
##### RSpec Testing
###### Running the tests
  * On the command line, run `bundle exec rspec`.
  * In order to run an individual file, run the command with the path to the spec file, e.g. `bundle exec rspec spec/models/article_spec.rb`
    * In order to run a single test within that file, include the line number the test starts on, e.g. `bundle exec rspec spec/models/article_spec.rb:35`
  * If you have a test that sometimes passes and sometimes fails (aka a "flaky test"), it's possible there is an order dependency in the tests. RSpec should output a "seed" number after each run, which determines the test order. You can re-run with the same order by running `bundle exec rspec --seed FAILING_SEED_NUMBER`. You can narrow down which order is creating the failure by using the `--bisect` flag, e.g. `bundle exec rspec --seed FAILING_SEED_NUMBER --bisect`. For more information, see https://relishapp.com/rspec/rspec-core/docs/command-line/bisect.

###### Creating Solr fixture objects (see `spec/support/oai_sample_solr_documents.rb` )
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
    * Or add it to the `.rubocop.yml` file, exluding either an individual file, or changing the configuration for a given rule.

#### Contact Information
* Email: cdr@unc.edu
