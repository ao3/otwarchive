class CollectionItem < ActiveRecord::Base

  NEUTRAL = 0
  APPROVED = 1
  REJECTED = -1
  
  APPROVAL_OPTIONS = [ [t('collection_item.neutral', :default => "Neutral"), NEUTRAL],
                         [t('collection_item.approved', :default => "Approved"), APPROVED],
                         [t('collection_item.rejected', :default => "Rejected"), REJECTED] ]

  belongs_to :collection
  belongs_to :item, :polymorphic => :true
  
  validates_uniqueness_of :collection_id, :scope => [:item_id, :item_type], 
    :message => t('collection_item.not_unique', :default => "That item appears to already be in that collection.")
  
  validates_numericality_of :user_approval_status, :allow_blank => true, :only_integer => true
  validates_inclusion_of :user_approval_status, :in => [-1, 0, 1], :allow_blank => true,
    :message => t('collection_item.invalid_status', :default => "That is not a valid approval status.")

  validates_numericality_of :collection_approval_status, :allow_blank => true, :only_integer => true
  validates_inclusion_of :collection_approval_status, :in => [-1, 0, 1], :allow_blank => true, 
    :message => t('collection_item.invalid_status', :default => "That is not a valid approval status.")
  
  validate :collection_is_open, :on => :create
  def collection_is_open
    errors.add_to_base t('collection_preferences.closed', :default => "Collection {{title}} is currently closed.", :title => self.collection.title) if self.collection && self.collection.closed?
  end
    
  after_save :approve_automatically
  def approve_automatically
    
    # approve with the current user, who is the person who has just
    # added this item -- might be either moderator or owner
    approve(User.current_user)

    # if the collection is open or the user who owns this work is a member, go ahead and approve
    # for the collection
    if collection
      if !collection.moderated? || collection.user_is_maintainer?(User.current_user) || (collection.user_is_posting_participant?(User.current_user) && !(item.pseuds & User.current_user.pseuds).empty?) 
        approve_by_collection
      end
    end

    # if at least one of the owners of the items automatically approves
    # adding or is a member of the collection, go ahead and approve by user
    if item
      item.users.each do |user|
        if user.preference.automatically_approve_collections || (collection && collection.user_is_posting_participant?(user))
          approve_by_user
          break
        end
      end
    end
  end
  
  def approve_by_user ; self.user_approval_status = APPROVED ; end  
  def approved_by_user? ; self.user_approval_status == APPROVED ; end
  def rejected_by_user? ; self.user_approval_status == REJECTED ; end
  
  def approve_by_collection ; self.collection_approval_status = APPROVED ; end
  def approved_by_collection? ; self.collection_approval_status == APPROVED ; end  
  def rejected_by_collection? ; self.collection_approval_status == REJECTED ; end 

  def reject(user)
    self.user_approval_status = REJECTED if item.users.include?(user)
    self.collection_approval_status = REJECTED unless (self.collection.maintainers & user.pseuds).empty?
  end

  def approve(user)
    self.user_approval_status = APPROVED if user && item.users.include?(user)
    self.collection_approval_status = APPROVED unless user && (self.collection.maintainers & user.pseuds).empty?
  end  

end