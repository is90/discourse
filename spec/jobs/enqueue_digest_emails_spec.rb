require 'spec_helper'
require_dependency 'jobs/base'

describe Jobs::EnqueueDigestEmails do


  describe '#target_users' do

    context 'disabled digests' do
      let!(:user_no_digests) { Fabricate(:active_user, email_digests: false, last_emailed_at: 8.days.ago, last_seen_at: 10.days.ago) }

      it "doesn't return users with email disabled" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user_no_digests.id)).to eq(false)
      end
    end

    context 'unapproved users' do
      Given!(:unapproved_user) { Fabricate(:active_user, approved: false, last_emailed_at: 8.days.ago, last_seen_at: 10.days.ago) }
      When { SiteSetting.stubs(:must_approve_users?).returns(true) }
      Then { expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(false) }

      # As a moderator
      And { unapproved_user.update_column(:moderator, true) }
      And { expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(true) }

      # As an admin
      And { unapproved_user.update_attributes(admin: true, moderator: false) }
      And { expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(true) }

      # As an approved user
      And { unapproved_user.update_attributes(admin: false, moderator: false, approved: true ) }
      And { expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(true) }
    end

    context 'recently emailed' do
      let!(:user_emailed_recently) { Fabricate(:active_user, last_emailed_at: 6.days.ago) }

      it "doesn't return users who have been emailed recently" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user_emailed_recently.id)).to eq(false)
      end

    end

    context "inactive user" do
      let!(:inactive_user) { Fabricate(:user, active: false) }

      it "doesn't return users who have been emailed recently" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(inactive_user.id)).to eq(false)
      end
    end

    context "suspended user" do
      let!(:suspended_user) { Fabricate(:user, suspended_till: 1.week.from_now, suspended_at: 1.day.ago) }

      it "doesn't return users who are suspended" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(suspended_user.id)).to eq(false)
      end
    end

    context 'visited the site this week' do
      let(:user_visited_this_week) { Fabricate(:active_user, last_seen_at: 6.days.ago) }
      let(:user_visited_this_week_email_always) { Fabricate(:active_user, last_seen_at: 6.days.ago, email_always: true) }

      it "doesn't return users who have been emailed recently" do
        user = user_visited_this_week
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user.id)).to eq(false)
      end

      it "does return users who have been emailed recently but have email_always set" do
        user = user_visited_this_week_email_always
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user.id)).to eq(true)
      end
    end

    context 'regular users' do
      let!(:user) { Fabricate(:active_user) }

      it "returns the user" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids).to eq([user.id])
      end
    end

  end

  describe '#execute' do

    let(:user) { Fabricate(:user) }

    before do
      Jobs::EnqueueDigestEmails.any_instance.expects(:target_user_ids).returns([user.id])
    end

    it "enqueues the digest email job" do
      Jobs.expects(:enqueue).with(:user_email, type: :digest, user_id: user.id)
      Jobs::EnqueueDigestEmails.new.execute({})
    end

  end


end

