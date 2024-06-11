# frozen_string_literal: true
require 'rake'
class TasksController < ApplicationController
  def run_dimensions_ingest_task
    Rails.application.load_tasks
    Rake::Task['dimensions:ingest_metadata'].invoke

    render plain: 'Rake task executed.'
  rescue => e
    render plain: "Failed to execute rake task: #{e.message}"
  end
  end
