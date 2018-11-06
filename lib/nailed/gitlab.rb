require 'gitlab'

require_relative './config'
require_relative '../nailed'
require_relative '../../db/model'

#
# Nailed:Gitlab
#
module Nailed
  #
  # gitlab helpers
  #
  def get_org_repos(gitlab_client, org)
    all_repos = gitlab_client.group_projects(org).auto_paginate
    all_repos.map(&:name)
  end

  def list_org_repos(gitlab_client, org)
    repos = get_org_repos(gitlab_client, org)
    repos.each { |r| puts "- #{r}" }
  end

  class Gitlab
    attr_reader :client

    def initialize
      Nailed::Config.parse_config
      endpoint = Nailed::Config.content["gitlab"]["endpoint"]
      private_token = Nailed::Config.content["gitlab"]["private_token"]
      @client = ::Gitlab.client(endpoint: endpoint, private_token: private_token)
    end

    def get_merge_requests(state: 'opened')
      Nailed.logger.info("Gitlab: #{__method__}")
      Nailed::Config.all_repositories['gitlab'].each do |repo|
        updated_mergerequests = []
        full_repo_name = "#{repo.organization.name}/#{repo.name}"
        Nailed.logger.info("#{__method__}: Getting #{state} mergerequests " \
                           "for #{full_repo_name}")
        begin
          retries ||= 0
          merges = @client.merge_requests("#{full_repo_name}", :state => state)
        rescue Exception => e
          retry if (retries += 1) < 2
          Nailed.logger.error("Could not get merges for #{full_repo_name}: #{e}")
          next
        end
        merges.each do |mr|
          attributes = { change_number: mr.iid,
                         title: mr.title,
                         state: mr.state=="opened"? 'open' : mr.state,
                         url: mr.web_url,
                         created_at: mr.created_at,
                         updated_at: mr.updated_at,
                         origin: "gitlab",
                         closed_at: nil,
                         merged_at: nil,
                         rname: repo.name,
                         oname: repo.organization.name }

          begin
            DB[:changerequests].insert_conflict(:replace).insert(attributes)
            updated_mergerequests.append(mr.iid)
          rescue Exception => e
            Nailed.logger.error("Could not write mergerequest:\n#{e}")
            next
          end

          Nailed.logger.debug(
            "#{__method__}: Created/Updated mergerequest #{repo.name} " \
            "##{mr.iid} with #{attributes.inspect}")
        end unless merges.empty?

        # check for old mergerequests of this repo and close them:
        Changerequest.select(:change_number, :state, :rname).where(state: "open", rname: repo.name, origin: "gitlab").each do |mr|
          unless updated_mergerequests.include? mr.change_number
            begin
              mr.update(state: "closed")
              Nailed.logger.info("Closed old mergerequest: #{repo.name}/#{mr.change_number}")
            rescue Exception => e
              Nailed.logger.error("Could not close mergerequest #{repo.name}/#{mr.change_number}:\n#{e}")
            end
          end
        end

        write_mergetrends(repo.organization.name, repo.name)
      end
    end

    def write_mergetrends(org, repo)
      Nailed.logger.info("#{__method__}: Writing merge trends for #{org}/#{repo}")
      open = Changerequest.where(rname: repo, state: "open", origin: "gitlab").count
      closed = Changerequest.where(rname: repo, state: "closed", origin: "gitlab").count
      attributes = { time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open: open,
                     closed: closed,
                     oname: org,
                     rname: repo,
                     origin: "gitlab" }

      begin
        DB[:changetrends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write merge trend for #{org}/#{repo}:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end

    def write_allmergetrends
      Nailed.logger.info("#{__method__}: Writing merge trends for all repos")
      open = Changerequest.where(state: "open", origin: "gitlab").count
      closed = Changerequest.where(state: "closed", origin: "gitlab").count
      attributes = { time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open: open,
                     closed: closed,
                     origin: "gitlab" }
      begin
        DB[:allchangetrends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write allmerge trend:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end
  end
end
