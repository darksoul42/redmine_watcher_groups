class WatcherGroupsController < ApplicationController

  before_filter :find_project
  # before_filter :require_login, :check_project_privacy, :only => [:watch, :unwatch]
  # before_filter :authorize, :only => [:new, :destroy]

  def new
  end

  def create
    if params[:watcher_group].is_a?(Hash) && request.post?
      if params[:object_type] == 'issue'
        issue = Issue.find(params[:object_id])
        group_ids = params[:watcher_group][:group_ids] || [params[:watcher_group][:group_id]]

        find_watcher_users = []
        group_ids.each do |group_id|
          group = Group.find(group_id)
          @watched.set_watcher_group(group, true)
          find_watcher_users = find_watcher_users | group.users
        end
        if find_watcher_users.any?
	  if Setting['plugin_redmine_watcher_groups']['redmine_watcher_groups_log_watchers_setting'] == 'yes'
	    if Redmine::Plugin.installed? :redmine_advanced_issue_history
	      notes = []
	      find_watcher_users.each do |user|
	        notes.append("Watcher #{user.name} was added")
	      end
	      add_system_journal(notes, issue)
	    else
	      issue.add_watcher_journal(:label_watcher_group_add, group_ids.flatten.compact.uniq.collect { |group_id| Group.find(group_id).name }.join(", "))
	    end
	  end
	end
      end
    end
    respond_to do |format|
      format.html { redirect_to_referer_or {render :text => 'Watcher group added.', :layout => true}}
      format.js
    end
  end

  def append
    if params[:watcher_group].is_a?(Hash)
      group_ids = params[:watcher_group][:group_ids] || [params[:watcher_group][:group_id]]
      @groups = Group.active.find_all_by_id(group_ids)
    end
  end

  def destroy
    if request.post?
      if params[:object_type] == 'issue'
        group = Group.find(params[:group_id])
        @watched.set_watcher_group(group, false) 
        issue = Issue.find(params[:object_id])
        group_users = group.users
        if group_users.any?
	  if Setting['plugin_redmine_watcher_groups']['redmine_watcher_groups_log_watchers_setting'] == 'yes'
	    if Redmine::Plugin.installed? :redmine_advanced_issue_history
	      notes = []
	      group_users.each do |user|
		notes.append("Watcher #{user.name} was removed")
	      end
	      add_system_journal(notes, issue)
	    else
	      issue.add_watcher_journal(:label_watcher_group_remove, group.name)
	    end
          end
        end
      end
    end
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end

  def autocomplete_for_group
    @groups = Group.sorted.active.like(params[:q]).limit(100)
    if @watched
      @groups -= @watched.watcher_groups
    end
    render :layout => false
  end

private
  def find_project
    if params[:object_type] && params[:object_id]
      klass = Object.const_get(params[:object_type].camelcase)
      @watched = klass.find(params[:object_id])
      return false unless @watched.respond_to?('watched_by_group?')
      @project = @watched.project
    elsif params[:project_id]
      @project = Project.visible.find_by_param(params[:project_id])
    end
  rescue
    render_404
  end

  def set_watcher_group(group, watching)
    @watched.set_watcher_group(group, watching)
    respond_to do |format|
      format.html { redirect_to_referer_or {render :text => (watching ? 'Watcher group added.' : 'Watcher group removed.'), :layout => true}}
      format.js { render :partial => 'set_watcher_group', :locals => {:group => group, :watched => @watched} }
    end
  end
end
