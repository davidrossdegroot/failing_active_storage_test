## To reproduce error https://github.com/rails/rails/issues/42295 
- create a database locally with the name active_storage_test

## Run using this command
`RAILS_ENV=test ruby -Ilib:test active_storage_gem.rb`

## Subsequent runs
- Comment out line 73 of active_storage_gem.rb