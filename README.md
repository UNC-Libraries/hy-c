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
* Pre-requisites (for Mac):
  * Docker Desktop - https://docs.docker.com/desktop/mac/install/
  * Homebrew (package manager for Mac) - https://brew.sh/
  * (optional) If you use Atom, get the Dockerfile specific grammar (may need to restart Atom to see effect) `apm install language-docker`
  * Mutagen-compose installed locally, used for speeding up file syncing between the host and guest systems. (on Mac, `brew install mutagen-io/mutagen/mutagen-compose`)

##### First-time setup, or if you've cleaned up Docker images or volumes
* If on an M1 Mac: check "Use the new Virtualization framework" in the Docker Desktop "Experimental Features" settings
* Clone the repository `git clone git@github.com:UNC-Libraries/hy-c.git`
* In the same parent directory, either
  * create a directory called `hyc-gems`, or
  * clone the private repository `git@gitlab.lib.unc.edu:cdr/hyc-gems.git` (*NOTE*: Must be on UNC VPN)
* cd into the hy-c repository `cd hy-c`

* Ensure you have the needed environment variables in `config/local_env.yml`. Either get a copy of this file from a colleague, use the `dev/local_env.yml` file from https://gitlab.lib.unc.edu/cdr/vagrant-rails/, or copy the sample file and fill in the appropriate values
```bash
cp config/local_env_sample.yml config/local_env.yml
  ```
- Either pull (faster) or build the application docker image
```bash
mutagen-compose pull
OR
mutagen-compose build --no-cache
```
##### Every time
- Bring up the application and its dependencies
```bash
mutagen-compose up
```
- In a new terminal window, in the hy-c directory, run this command in order to go into a bash shell inside the running web container (hy-c-web-1)
```bash
docker compose exec web bash
```
    - So, if you wanted to run the tests:
    ```bash
    mutagen-compose up web
    [new terminal window or tab]
    docker compose exec web bash
    bundle exec rspec spec/models
    ```
- You can edit the code in your editor, as usual, and the changes will be reflected inside the docker container.
- You should be able to see the application at http://localhost:3000/
- If you are experiencing slow performance, you might want to increase the resources available to your Docker network, including CPUs, memory, and swap. If you're working on a Mac, go to Docker Desktop, click the gear icon -> Resources -> Advanced, drag the resources bars to the desired levels, and then click Apply & Restart

- One configuration that seems to be working is:
  - CPUs: 8
  - Memory: 12GB
  - Swap: 2 GB
  - Disk image size: 200 GB

- In order to stop the application and services, you can do a ctrl-c inside the window where you ran `mutagen-compose up`, or you can click the "stop" button in Docker Desktop in the containers/apps section.

##### Docker debugging notes
* Updates to the code should be picked up pretty immediately - there could be a second or so lag, but it should be fairly instantaneous.
* When your Solr, Fedora, and Postgres get out of sync, it might be easiest to stop the application and dependencies (`mutagen-compose stop`), delete the volumes for all three of these, then bring everything back up.
* If you change volume permissions via the docker-compose file, you will need to delete the existing volumes before you see any changes.
* If you get a message like:
```
Error response from daemon: driver failed programming external connectivity on endpoint hy-c-db-1 (long_hash): Bind for 0.0.0.0:5432 failed: port is already allocated
```
  You may have a service already running locally, so you can either stop the service running locally, or map the service externally to another port (the left side of the `port` stanza in the `docker-compose.yml` file)

#### Testing
##### RSpec Testing
* Setting up for the first time (we are hoping to move away from needing this, but some tests still expect this to have been run)
```bash
bundle exec rake test_setup RAILS_ENV=test
```
* To run the entire test suite (this takes from 20-30 minutes locally)
```bash
bundle exec rspec
```
* To run an individual test
```bash
bundle exec rspec spec/path/to/test.rb:line_number
aka
bundle exec rspec spec/models/jats_ingest_work_spec.rb:7
```

##### Debugging intermittent test failures
* Our tests are set up to run in a random order, which can sometimes surface unexpected dependencies in our code. In order to re-create a failing test run, use the seed number printed at the end of the test.
```bash
foo@bar:~$ bundle exec rspec spec/controllers/hyrax/users_controller_spec.rb
[...]
6 examples, 1 failure

Randomized with seed 44409

foo@bar:~$ bundle exec rspec spec/controllers/hyrax/users_controller_spec.rb --seed 44409
```

*NOTE*: FFaker uses its own seed in order to randomize usernames, etc., in the test factories. If your test is inconsistent even with the same seed, you might look into whether different FFaker-generated values are to blame. See https://github.com/ffaker/ffaker/blob/main/RANDOM.md for more information.

##### Creating Solr fixture objects (see `spec/support/oai_sample_solr_documents.rb` )
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
