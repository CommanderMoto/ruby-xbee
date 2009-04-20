require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "ruby-xbee"
    gem.summary = %Q{Ripped ruby-xbee-1.0 from http://sawdust.see-do.org/ruby-xbee/releases/ruby-xbee-1.0/ruby-xbee-1.0.tar.gz
                     on 20 April 2009; heavy modifications underway to support V2 XBee Pro 900MHz modules and generally 
                     clean up code}
    gem.email = "mike@motomike.net"
    gem.homepage = "http://github.com/motomike/ruby-xbee"
    gem.authors = ["Mike Ashmore"]
    gem.require_paths = ['lib']
    gem.autorequire = 'ruby_xbee'
    gem.add_dependency 'ruby-serialport'
  
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end


task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION.yml')
    config = YAML.load(File.read('VERSION.yml'))
    version = "#{config[:major]}.#{config[:minor]}.#{config[:patch]}"
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "ruby-xbee #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

