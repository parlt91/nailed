require 'yaml'

require_relative '../nailed'

module Nailed
  class Config
    class << self
      def parse_config
        is_valid?

        # init class variables:
        init_git
        organizations.keys.each do |git|
          (load_content[git]['organizations'] || []).each do |org|
            org_obj = Organization.new(org['name'])
            org['repositories'].each do |repo|
              org_obj.repositories.add(repo)
            end
            @@organizations[git].push(org_obj)
          end

          @@organizations[git].each do |org|
            @@all_repositories[git].concat(org.repositories.to_a)
          end
        end
      end

      def is_valid?
        if load_content.nil? || load_content.empty?
          abort("Config empty or corrupted")
        elsif load_content['products'].nil? || load_content['products'].empty?
          abort("Config incomplete: No products found")
        end
        true
      end

      # attr_accessor:
      def products
        @@components = Hash.new
        products = load_content['products'].clone
        products.each_index do |x|
          if products[x].class == Hash
            hash_components(products[x])
            products[x] = products[x].keys.first
          end
        end
      end

      def components
        @@components
      end

      def organizations
        @@organizations
      end

      def all_repositories
        @@all_repositories
      end

      def content
        load_content
      end

      private

      def hash_components(product)
        @@components[product.keys.first]=product.values.last unless product.fetch("components",nil).nil?
      end

      def init_git
        @@organizations = {}
        @@all_repositories = {}
        ['github','gitlab'].each do |git|
          if !content[git].nil?
            @@organizations[git] = []
            @@all_repositories[git] = []
          end
        end
      end

      def load_content
        path_to_config ||= File.join(__dir__, "..", "..", "config", "config.yml")
        begin
          @@content ||= YAML.load_file(path_to_config)
        rescue Exception => e
          STDERR.puts("Can't load '#{path_to_config}': #{e}")
          exit 1
        end
      end
    end
  end
end
