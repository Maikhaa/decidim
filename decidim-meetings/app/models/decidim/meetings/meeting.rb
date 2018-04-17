# frozen_string_literal: true

module Decidim
  module Meetings
    # The data store for a Meeting in the Decidim::Meetings component. It stores a
    # title, description and any other useful information to render a custom meeting.
    class Meeting < Meetings::ApplicationRecord
      include Decidim::Resourceable
      include Decidim::HasAttachments
      include Decidim::HasAttachmentCollections
      include Decidim::HasComponent
      include Decidim::HasReference
      include Decidim::ScopableComponent
      include Decidim::HasCategory
      include Decidim::Followable
      include Decidim::Comments::Commentable
      include Decidim::Traceable
      include Decidim::Loggable

      belongs_to :organizer, foreign_key: "organizer_id", class_name: "Decidim::User", optional: true
      has_many :registrations, class_name: "Decidim::Meetings::Registration", foreign_key: "decidim_meeting_id", dependent: :destroy

      component_manifest_name "meetings"

      validates :title, presence: true
      validate :organizer_belongs_to_organization

      geocoded_by :address, http_headers: ->(proposal) { { "Referer" => proposal.component.organization.host } }

      scope :past, -> { where(arel_table[:end_time].lteq(Time.current)) }
      scope :upcoming, -> { where(arel_table[:start_time].gt(Time.current)) }

      scope :visible_meeting_for, lambda { |user|
                                    joins("LEFT JOIN decidim_meetings_registrations ON
                                    decidim_meetings_registrations.decidim_meeting_id = #{table_name}.id")
                                      .where("(is_private = ? and decidim_meetings_registrations.decidim_user_id = ?)
                                    or is_private = ? or (is_private = ? and is_transparent = ?)", true, user, false, true, true).distinct
                                  }

      def self.log_presenter_class_for(_log)
        Decidim::Meetings::AdminLog::MeetingPresenter
      end

      def closed?
        closed_at.present?
      end

      def has_available_slots?
        return true if available_slots.zero?
        (available_slots - reserved_slots) > registrations.count
      end

      def remaining_slots
        available_slots - reserved_slots - registrations.count
      end

      def has_registration_for?(user)
        registrations.where(user: user).any?
      end

      # Public: Overrides the `commentable?` Commentable concern method.
      def commentable?
        component.settings.comments_enabled?
      end

      # Public: Overrides the `accepts_new_comments?` Commentable concern method.
      def accepts_new_comments?
        commentable? && !component.current_settings.comments_blocked
      end

      # Public: Overrides the `comments_have_alignment?` Commentable concern method.
      def comments_have_alignment?
        true
      end

      # Public: Overrides the `comments_have_votes?` Commentable concern method.
      def comments_have_votes?
        true
      end

      # Public: Override Commentable concern method `users_to_notify_on_comment_created`
      def users_to_notify_on_comment_created
        followers
      end

      def can_participate?(user)
        return true unless participatory_space.try(:private_space?)
        return true if participatory_space.try(:private_space?) && participatory_space.users.include?(user)
        return false if participatory_space.try(:private_space?) && participatory_space.try(:is_transparent?)
      end

      def can_view_meeting?(current_user)
        return true unless self.try(:is_private?)
        return true if is_private? && registrations.exists?(decidim_user_id: current_user.try(:id))
        return false if is_private? && is_transparent?
      end

      def organizer_belongs_to_organization
        return if !organizer || !organization
        errors.add(:organizer, :invalid) unless organizer.organization == organization
      end

      def official?
        organizer.nil?
      end
    end
  end
end
