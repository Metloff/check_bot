class WebhooksController < ApplicationController
  def callback
    return if webhook[:message].blank?
    ::Bot::MessageParser.new(webhook, user).run
    render nothing: true, head: :ok
  end


  ## helpers
  def webhook
    params['webhook']
  end

  def from
    webhook[:message][:from]
  end

  def user
    User.user_processing(from)
  end
end
