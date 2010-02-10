require File.expand_path(File.dirname(__FILE__) + '/../data_loader')

# require 'htmlentities'

namespace :edms do
  include Edms::DataLoader
  
  desc "Populate data for Edms in DB"
  task :load_edms => :environment do
    load_edms
  end
end