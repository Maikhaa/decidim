# frozen_string_literal: true

module Decidim
  module Meetings
    # The data store for a Minute in the Decidim::Meetings component.

    class Minute < Meetings::ApplicationRecord

      belongs_to :meeting, foreign_key: "decidim_meeting_id", class_name: "Decidim::Meetings::Meeting"

    end
  end
end
