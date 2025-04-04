# frozen_string_literal: true

##
# Dummy request objects for spec testing
# These test validations, transformations, type coercions, and nested behavior.

class AnyClass; end

class GenreRequest
  include InteractorSupport::RequestObject

  attribute :title, transform: :strip
  attribute :description, transform: :strip

  validates :title, :description, presence: true
end

class LocationRequest
  include InteractorSupport::RequestObject

  attribute :city, transform: [:downcase, :strip]
  attribute :country_code, transform: [:strip, :upcase]
  attribute :state_code, transform: [:strip, :upcase]
  attribute :postal_code, transform: [:strip, :clean_postal_code]
  attribute :address, transform: :strip

  validates :city, :postal_code, :address, presence: true
  validates :country_code, :state_code, presence: true, length: { is: 2 }

  def clean_postal_code(value)
    value.to_s.gsub(/\D/, '')[0, 5]
  end
end

class AuthorRequest
  include InteractorSupport::RequestObject

  attribute :name, transform: :strip
  attribute :email, transform: [:strip, :downcase]
  attribute :age, transform: :to_i
  attribute :location, type: LocationRequest

  validates_format_of :email, with: URI::MailTo::EMAIL_REGEXP
end

class PostRequest
  include InteractorSupport::RequestObject

  attribute :user_id
  attribute :title, transform: :strip
  attribute :content, transform: :strip
  attribute :genre, type: GenreRequest
  attribute :authors, type: AuthorRequest, array: true
end

class TypeRequest
  include InteractorSupport::RequestObject

  attribute :genre, type: :string
  attribute :author_ids, type: :integer, array: true
  attribute :genres, type: :string, array: true

  attribute :some_integer, type: :integer
  attribute :some_string, type: :string
  attribute :some_float, type: :float
  attribute :some_true, type: :boolean
  attribute :some_false, type: :boolean
  attribute :some_array, type: Array
  attribute :some_hash, type: Hash
  attribute :some_symbol, type: Symbol
  attribute :some_class, type: AnyClass
  attribute :some_date_time, type: :datetime
  attribute :some_unsupported, type: :unsupported
  attribute :some_unsupported_primitive, type: Rational
end

class ImageUploadRequest
  include InteractorSupport::RequestObject

  attribute :image, rewrite: :image_url, transform: :strip
end
