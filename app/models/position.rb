class Position < ApplicationRecord

  # #############################################################
  # Associations

  belongs_to :check

  has_many :details
  has_many :users, :through => :details

  # #############################################################
  # Validations

  validates :title, :presence => true, :length => { :maximum => 250 }
  validates :number_of_people, numericality: {:only_integer => true, greater_than: 0 }
  validates :price, numericality: { greater_than: 0 }

  # #############################################################
  # Callbacks

  after_create :set_custom_id




  def set_custom_id
    self.update_attributes(:custom_id => (self.check.positions.count))
  end
end
