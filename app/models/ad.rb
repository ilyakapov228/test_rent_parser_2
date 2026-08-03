class Ad < ApplicationRecord
  validates :external_id, :site, :url, presence: true
  validates :external_id, uniqueness: { scope: :site }
end
