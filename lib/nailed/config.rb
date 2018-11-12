require 'yaml'

require_relative '../nailed'

module Nailed
  class Config
    class << self

      # list of supported version-control-systems
      @@supported_vcs = [ 'github', 'gitlab' ]

      def parse_config
        is_valid?

        # init class variables for supported VCS's
        init_vcs

        # init class variables:
        organizations.keys.each do |vcs|
          (load_content[vcs]['organizations'] || []).each do |org|
            org_obj = Organization.new(org['name'])
            org['repositories'].each do |repo|
              org_obj.repositories.add(repo)
            end
            @@organizations[vcs].push(org_obj)
          end

          @@organizations[vcs].each do |org|
            @@all_repositories[vcs].concat(org.repositories.to_a)
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

      def supported_vcs
        @@supported_vcs
      end

      def content
        load_content
      end

      private

      def hash_components(product)
        @@components[product.keys.first]=product.values.last unless product.fetch("components",nil).nil?
      end

      def init_vcs
        @@organizations = {}
        @@all_repositories = {}
        @@supported_vcs.each do |vcs|
          if content.keys.map(&:downcase).include?(vcs)
            @@organizations[vcs] = []
            @@all_repositories[vcs] = []
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
