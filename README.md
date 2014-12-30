## What is nailed?

`nailed` consists of a back-end CLI for data collection and a sinatra based web front-end for visualization of relevant development data of Products that have their bugtracker on Bugzilla and (optionally) their codebase on GitHub.

`Be aware` that the bugzilla layout (metadata) is still SUSE specific, which may not be useful for everybody.
e.g. it relies on bugs being tagged as L3. The plan is to make it optional in the future.

## Installation
`gem install 'nailed'`

## Usage

```
$ nailed -h
Options:
      --migrate, -m:   Set database to pristine state
      --upgrade, -u:   Upgrade database
     --bugzilla, -b:   Refresh bugzilla database records
       --github, -g:   Refresh github database records
           --l3, -l:   Refresh l3 trend database records
       --server, -s:   Start a dashboard webinterface
         --help, -h:   Show this message
```

## Initial setup

* for the bugzilla API make sure you have an `.oscrc` file with your credentials in ~
* for the github API make sure you have a `.netrc` with a valid GitHub OAuth-Token in ~
```
# example .netrc

machine api.github.com
  login MaximilianMeister
  password <your OAuth Token>
```
* to setup the database run
```
nailed --migrate
```

## Configuration

All configuration is read from `config/products.yml`

``` yaml
---
bugzilla:
  url: # Url of your Bugzilla instance
products:
  example_product: # Just a a short key/name for the product (can be arbitrary)
    versions:
    # Array of Bugzilla products (typically different versions of one product)
    # Exact names have to be given, as they appear in Bugzilla (can not be arbitrary)
    organization: # here goes the organization name (under which your repos are hosted) as it appears in GitHub
    # just leave it blank if your repo isn't hosted under an organizational umbrella
    repos:
    # Array of GitHub repository names, as they appear in GitHub
    # If there are no associated repos for the product, just leave it blank
  # continue adding more products here

```

* in production, after adding products/changes, to upgrade the database with the new changes run
```
nailed --upgrade
```

## Run

* create a `cronjob` for automated data collection with `nailed`
* start the webserver with `nailed --server`