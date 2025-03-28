# **InteractorSupport** 🚀

Make your **Rails interactors** clean, powerful, and less error-prone!

[![Coverage Status](https://coveralls.io/repos/github/charliemitchell/interactor_support/badge.svg)](https://coveralls.io/github/charliemitchell/interactor_support)  
[![Ruby](https://github.com/charliemitchell/interactor_support/actions/workflows/main.yml/badge.svg?branch=master)](https://github.com/charliemitchell/interactor_support/actions/workflows/main.yml)  
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/2a0750b6e87b4a288f568d49d45f6a6c)](https://app.codacy.com/gh/charliemitchell/interactor_support/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

---

## 🚀 **What Is InteractorSupport?**

`InteractorSupport` **extends the Interactor pattern** to make your **business logic more concise, expressive, and robust.**

### ✅ **Why Use It?**

- **Automatic Validations** – Validate inputs before execution
- **Data Transformations** – Trim, downcase, and sanitize with ease
- **Transactional Execution** – Keep data safe with rollback support
- **Conditional Skipping** – Skip execution based on logic
- **Auto Record Lookup & Updates** – Reduce boilerplate code
- **Request Objects** – Lean on **ActiveModel** for structured, validated inputs

---

## 📦 **Installation**

Add to your Gemfile:

```sh
gem 'interactor_support', '~> 1.0', '>= 1.0.1'
```

Or install manually:

```sh
gem install interactor_support
```

It is reccommended that you use Rails 7.1.x and above with this gem. However, it will work with older versions of rails. You may encounter the issue below when using Rails versions prior to 7.1.

```
<module:LoggerThreadSafeLevel>: uninitialized constant ActiveSupport::LoggerThreadSafeLevel::Logger (NameError)
```

In that case, you need to add `require "logger"` as the first line to your `boot.rb file` or pin the concurrent-ruby version to `gem 'concurrent-ruby', '1.3.4'`. If feasible, consider upgrading your Rails application to version 7.1 or newer, where this compatibility issue has been addressed.

---

## 🚦 **Getting Started**

### **The Problem: Messy Interactors**

Without `InteractorSupport`

```ruby
class UpdateTodoTitle
  include Interactor

  def call
    todo = Todo.find_by(id: context.todo_id)
    return context.fail!(error: "Todo not found") if todo.nil?

    todo.update!(title: context.title.strip, completed: context.completed)
    context.todo = todo
  end
end
```

**Problems:**

❌ Repetitive boilerplate  
❌ Manual failure handling  
❌ No automatic transformations

---

### **The Solution: InteractorSupport**

With InteractorSupport, your interactor is now elegant and expressive:

```rb
class UpdateTodoTitle
  include Interactor
  include InteractorSupport

  required :todo_id, :title
  transform :title, with: :strip
  find_by :todo, query: { id: :todo_id }, required: true
  update :todo, attributes: { title: :title }

  def call
    context.message = "Todo updated!"
  end
end
```

**🚀 What changed?**

✅ Self documenting validation using `requires`
✅ Trimmed the title with `transform`
✅ Automatic record lookup with `find_by`
✅ Automatic update with `update`

### Making it even more powerful

```rb
class CompleteTodo
  include Interactor
  include InteractorSupport

  transaction
  required :todo_id
  find_by :todo, query: { id: :todo_id }, required: true

  update :todo, attributes: {
    completed: true,
    completed_at: -> { Time.current }
  }
end
```

✅ Wraps the interactor in an active record transaction
✅ Self documenting validation using `requires`
✅ Automatic record lookup with `find_by`
✅ Automatic update with `update` using static values, and a context aware lambda.

### Skipping execution when it's not needed

```rb
class CompleteTodo
  include Interactor
  include InteractorSupport

  transaction
  required :todo
  skip if: -> { todo.completed? }
  update :todo, attributes: { completed: true, completed_at: -> { Time.current } }
end
```

## 📜 **Request Objects – Lean on Rails Conventions**

Instead of raw hashes, **Request Objects** provide **validation, transformation, and structure**.

### ✅ **Built on ActiveModel**

- Works just like an **ActiveRecord model**
- Supports **validations** out of the box
- Automatically **transforms & sanitizes** data

```ruby
class TodoRequest
  include InteractorSupport::RequestObject

  attribute :title, transform: :strip
  attribute :email, transform: [:strip, :downcase]
  attribute :completed, type: Boolean, default: false

  validates :title, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
```

---

## 📖 **Documentation**

### **Modules & Features**

#### 🔹 **`InteractorSupport::Concerns::Updatable`**

Provides the `update` method to **automatically update records** based on context.

```rb
# example incantations
update :todo, attributes: { title: :title } # -> context.todo.update!(title: context.title)
update :todo, attributes: { title: :title }, context_key: :updated_todo # -> context.updated_todo = context.todo.update!(title: context.title)
update :todo, attributes: { request: { title: :title } } # -> context.todo.update!(title: context.request.title)
update :todo, attributes: { request: [:title, :completed] } # -> context.todo.update!(title: context.request.title, completed: context.request.completed)
update :todo, attributes: :request # -> context.todo.update!(context.request)
update :todo, attributes: [:title, :completed] # -> context.todo.update!(title: context.title, completed: context.completed)
update :todo, attributes: { title: :title, completed: true, completed_at: -> { Time.zone.now } } # -> context.todo.update!(title: context.title, completed: true, completed_at: Time.zone.now)
```

#### 🔹 **`InteractorSupport::Concerns::Findable`**

Provides `find_by` and `find_where` to **automatically locate records**.

```rb
# example incantations

# Genre.find_by(id: context.genre_id)
find_by :genre, context_key: :current_genre

# lambdas are executed within the interactor's context, can be anything needed to compute at runtime
# Genre.find_by(name: context.name, created_at: context.some_context_value )
find_by :genre, query: { name: :name, created_at: -> { some_context_value } }
find_by :genre, query: { name: :name, created_at: -> { 7.days.ago...1.day.ago } }

# be careful here, this is not advisable.
find_by :genre, query: { name: :name, created_at: 7.days.ago...1.day.ago }

# Genre.find_by(name: context.name)
find_by :genre, query: { name: :name }

# context.current_genre = Genre.find_by(id: context.genre_id)
find_by :genre, context_key: :current_genre

# Genre.find_by(id: context.genre_id), fails the context if the result is nil
find_by :genre, required: true

# find_where
# Post.where(user_id: context.user_id)
find_where :post, where: { user_id: :user_id }

# Same as above, but will fail the context if the results are empty
find_where :post, where: { user_id: :user_id }, required: true

# lambdas are executed within the interactor's context
# Post.where(user_id: context.user_id, created_at: context.some_context_value )
find_where :post, where: { user_id: :user_id, created_at: -> { some_context_value } }

# Post.where(user_id: context.user_id).where.not(active: false)
find_where :post, where: { user_id: :user_id }, where_not: { active: false }

# Post.active.where(user_id: context.user_id)
find_where :post, where: { user_id: :user_id }, scope: :active

# context.user_posts = Post.where(user_id: context.user_id)
find_where :post, where: { user_id: :user_id }, context_key: :user_posts
```

#### 🔹 **`InteractorSupport::Concerns::Transformable`**

Provides `transform` to **sanitize and normalize inputs**.

```rb
# any method that the attribute responds to will work
transform :title, with: :strip

# You can chain transformers on an attribute
# show_the_thing == "1" => "1".to_i.positive? => true
transform :show_the_thing, with: [:to_i, :positive?]

# transforming a string to a boolean using a lambda, eg: "true" => true
transform :my_param, with: -> (val) { ActiveModel::Type::Boolean.new.cast(val) }

# added in 1.0.2
# mixing symbols and keys. eg: " True     " => true
transform :my_param, with: [
  :strip,
  :downcase,
  -> (val) { ActiveModel::Type::Boolean.new.cast(val) }
]

```

#### 🔹 **`InteractorSupport::Concerns::Skippable`**

Allows an interactor to **skip execution** if a condition is met.

```rb
# skips execution
skip if: true
# skips execution when a lambda is passed
skip if: -> { true }
# using a method
skip if: :some_method?
# using a context variable
skip if: :condition

# Using `unless`

# skips execution
skip unless: false
# skips execution when a lambda is passed
skip unless: -> { false }
# using a method
skip unless: :some_method?
# using a context variable
skip unless: :condition
```

#### 🔹 **`InteractorSupport::Validations`**

Provides **automatic input validation** before execution. This includes `ActiveModel::Validations` and
`ActiveModel::Validations::Callbacks`, and adds a few extra methods.

| method           | description                                                                                                                                                                            |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| required         | a self documenting helper method that registers the attribute as an accessor, applies any active model validations passed to it. If the attribute is missing, it will fail the context |
| optional         | a self documenting helper method that registers the attribute as an accessor, applies any active model validations passed to it using `:if_assigned`                                   |
| validates_after  | An after validator to ensure context consistancy.                                                                                                                                      |
| validates_before | will likely be deprecated in the future.                                                                                                                                               |

```rb
class CreateUser
  include Interactor
  include InteractorSupport

  required email: { format: { with: URI::MailTo::EMAIL_REGEXP } },
           password: { length: { minimum: 6 } }

  optional age: { numericality: { greater_than: 18 } }
  validates_after :user, persisted: true
end
```

✅ email must be present and match a valid format
✅ password must be present and at least 6 characters long
✅ age is optional but must be greater than 18 if provided

If any validation fails, context.fail!(errors: errors.full_messages) will automatically halt execution.

#### 🔹 **`InteractorSupport::RequestObject`**

Provides structured, validated request objects based on **ActiveModel**.

For now, here's the specs:

```rb
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
    value.to_s.gsub(/\D/, '')
    value.first(5)
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

RSpec.describe(InteractorSupport::RequestObject) do
  describe 'attribute transformation' do
    before do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_self
      end
    end
    context 'when using a single transform' do
      it 'strips the value for a symbol transform' do
        genre = GenreRequest.new(title: '  Science Fiction  ', description: ' A genre of speculative fiction  ')
        expect(genre.title).to(eq('Science Fiction'))
        expect(genre.description).to(eq('A genre of speculative fiction'))
      end
    end

    context 'when using an array of transforms' do
      it 'applies all transform methods in order' do
        buyer = LocationRequest.new(
          city: '  New York  ',
          country_code: '  us  ',
          state_code: '  ny  ',
          postal_code: '  10001-5432  ',
          address: '  123 Main St.  ',
        )
        expect(buyer.city).to(eq('new york'))
        expect(buyer.country_code).to(eq('US'))
        expect(buyer.state_code).to(eq('NY'))
        expect(buyer.postal_code).to(eq('10001'))
        expect(buyer.address).to(eq('123 Main St.'))
      end
    end

    context 'when the value does not respond to a transform method' do
      it 'raises and argument error if the transform method is not defined' do
        class DummyRequest
          include InteractorSupport::RequestObject
          attribute :number, transform: :strip
          validates :number, presence: true
        end

        expect { DummyRequest.new(number: 1234) }.to(raise_error(ArgumentError))
      end
    end
  end

  describe 'nesting request objects and array support' do
    before do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_self
      end
    end
    context 'when using a type without array' do
      it "wraps the given hash in the type's new instance" do
        post = PostRequest.new(
          user_id: 1,
          title: '  My First Post  ',
          content: '  This is the content of my first post  ',
          genre: { title: '  Science Fiction  ', description: ' A genre of speculative fiction  ' },
          authors: [
            {
              name: '  John Doe  ',
              email: 'me@mail.com',
              age: '  25  ',
              location: {
                city: '  New York  ',
                country_code: '  us  ',
                state_code: '  ny  ',
                postal_code: '  10001-5432  ',
                address: '  123 Main St.  ',
              },
            },
            {
              name: '  Jane Doe  ',
              email: 'you@mail.com',
              age: '  25  ',
              location: {
                city: '  Los Angeles  ',
                country_code: '  us  ',
                state_code: '  ca  ',
                postal_code: '  90001  ',
                address: '  456 Elm St.  ',
              },
            },
          ],
        )

        expect(post).to(be_valid)
        expect(post.user_id).to(eq(1))
        expect(post.title).to(eq('My First Post'))
        expect(post.content).to(eq('This is the content of my first post'))
        expect(post.genre).to(be_a(GenreRequest))
        expect(post.genre.title).to(eq('Science Fiction'))
        expect(post.genre.description).to(eq('A genre of speculative fiction'))
        expect(post.authors).to(be_an(Array))
        expect(post.authors.size).to(eq(2))
        post.authors.each do |author|
          expect(author).to(be_a(AuthorRequest))
          expect(author).to(be_valid)
          expect(author.location).to(be_a(LocationRequest))
          expect(author.location).to(be_valid)
          expect(author.location.city).to(be_in(['new york', 'los angeles']))
          expect(author.location.country_code).to(eq('US'))
          expect(author.location.state_code).to(be_in(['NY', 'CA']))
          expect(author.location.postal_code).to(be_in(['10001', '90001']))
          expect(author.location.address).to(be_in(['123 Main St.', '456 Elm St.']))
        end
      end
    end
  end

  describe 'to_context' do
    before do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_self
      end
    end
    it 'returns a struct and includes nested attributes' do
      context = PostRequest.new(
        user_id: 1,
        title: '  My First Post  ',
        content: '  This is the content of my first post  ',
        genre: { title: '  Science Fiction  ', description: ' A genre of speculative fiction  ' },
        authors: [
          {
            name: '  John Doe  ',
            email: 'a@b.com',
            age: '  25  ',
            location: {
              city: '  New York  ',
              country_code: '  us  ',
              state_code: '  ny  ',
              postal_code: '  10001-5432  ',
              address: '  123 Main St.  ',
            },
          },
        ],
      ).to_context

      expect(context).to(be_a(Hash))
      expect(context[:user_id]).to(eq(1))
      expect(context[:title]).to(eq('My First Post'))
      expect(context[:content]).to(eq('This is the content of my first post'))
      expect(context[:genre]).to(be_a(Hash))
      expect(context.dig(:genre, :title)).to(eq('Science Fiction'))
      expect(context.dig(:genre, :description)).to(eq('A genre of speculative fiction'))
      expect(context[:authors]).to(be_an(Array))
      expect(context[:authors].size).to(eq(1))
      author = context[:authors].first
      expect(author).to(be_a(Hash))
      expect(author[:name]).to(eq('John Doe'))
      expect(author[:email]).to(eq('a@b.com'))
      expect(author[:age]).to(eq(25))
      expect(author[:location]).to(be_a(Hash))
      expect(author[:location][:city]).to(eq('new york'))
      expect(author[:location][:country_code]).to(eq('US'))
    end
  end

  describe 'configured request object behavior' do
    it 'returns a context hash with symbol keys when configured to do so' do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_context
        config.request_object_key_type = :symbol
      end

      context = PostRequest.new(
        user_id: 1,
        title: '  My First Post  ',
        content: '  This is the content of my first post  ',
        genre: { title: '  Science Fiction  ', description: ' A genre of speculative fiction  ' },
        authors: [
          {
            name: '  John Doe  ',
            email: 'j@j.com',
            age: '  25  ',
            location: {
              city: '  New York  ',
              country_code: '  us  ',
              state_code: '  ny  ',
              postal_code: '  10001-5432  ',
              address: '  123 Main St.  ',
            },
          },
        ],
      )

      expect(context).to(be_a(Hash))
      expect(context[:user_id]).to(eq(1))
      expect(context[:title]).to(eq('My First Post'))
      expect(context[:content]).to(eq('This is the content of my first post'))
      expect(context[:genre]).to(be_a(Hash))
      expect(context.dig(:genre, :title)).to(eq('Science Fiction'))
      expect(context.dig(:genre, :description)).to(eq('A genre of speculative fiction'))
      expect(context[:authors]).to(be_an(Array))
      expect(context[:authors].size).to(eq(1))
      author = context[:authors].first
      expect(author).to(be_a(Hash))
      expect(author[:name]).to(eq('John Doe'))
      expect(author[:email]).to(eq('j@j.com'))
      expect(author[:age]).to(eq(25))
      expect(author[:location]).to(be_a(Hash))
      expect(author[:location][:city]).to(eq('new york'))
      expect(author[:location][:country_code]).to(eq('US'))
    end

    it 'returns a context hash with string keys when configured to do so' do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_context
        config.request_object_key_type = :string
      end

      post = PostRequest.new(
        user_id: 1,
        title: '  My First Post  ',
        content: '  This is the content of my first post  ',
        genre: { title: '  Science Fiction  ', description: ' A genre of speculative fiction  ' },
        authors: [
          {
            name: '  John Doe  ',
            email: 'j@j.com',
            age: '  25  ',
            location: {
              city: '  New York  ',
              country_code: '  us  ',
              state_code: '  ny  ',
              postal_code: '  10001-5432  ',
              address: '  123 Main St.  ',
            },
          },
        ],
      )

      context = post
      expect(context).to(be_a(Hash))
      expect(context['user_id']).to(eq(1))
      expect(context['title']).to(eq('My First Post'))
      expect(context['content']).to(eq('This is the content of my first post'))
      expect(context['genre']).to(be_a(Hash))
      expect(context.dig('genre', 'title')).to(eq('Science Fiction'))
      expect(context.dig('genre', 'description')).to(eq('A genre of speculative fiction'))
      expect(context['authors']).to(be_an(Array))
      expect(context['authors'].size).to(eq(1))
      author = context['authors'].first
      expect(author).to(be_a(Hash))
      expect(author['name']).to(eq('John Doe'))
      expect(author['email']).to(eq('j@j.com'))
      expect(author['age']).to(eq(25))
      expect(author['location']).to(be_a(Hash))
      expect(author['location']['city']).to(eq('new york'))
      expect(author['location']['country_code']).to(eq('US'))
    end

    it 'returns a context struct when configured to do so' do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_context
        config.request_object_key_type = :struct
      end

      post = PostRequest.new(
        user_id: 1,
        title: '  My First Post  ',
        content: '  This is the content of my first post  ',
        genre: { title: '  Science Fiction  ', description: ' A genre of speculative fiction  ' },
        authors: [
          {
            name: '  John Doe  ',
            email: 'j@j.com',
            age: '  25  ',
            location: {
              city: '  New York  ',
              country_code: '  us  ',
              state_code: '  ny  ',
              postal_code: '  10001-5432  ',
              address: '  123 Main St.  ',
            },
          },
        ],
      )

      context = post
      expect(context).to(be_a(Struct))
      expect(context.user_id).to(eq(1))
      expect(context.title).to(eq('My First Post'))
      expect(context.content).to(eq('This is the content of my first post'))
      expect(context.genre).to(be_a(Struct))
      expect(context.genre.title).to(eq('Science Fiction'))
      expect(context.genre.description).to(eq('A genre of speculative fiction'))
      expect(context.authors).to(be_an(Array))
      expect(context.authors.size).to(eq(1))
      author = context.authors.first
      expect(author).to(be_a(Struct))
      expect(author.name).to(eq('John Doe'))
      expect(author.email).to(eq('j@j.com'))
      expect(author.age).to(eq(25))
      expect(author.location).to(be_a(Struct))
      expect(author.location.city).to(eq('new york'))
      expect(author.location.country_code).to(eq('US'))
    end
  end
end
```

## 🤝 **Contributing**

Pull requests are welcome on [GitHub](https://github.com/charliemitchell/interactor_support).

---

## 📜 **License**

Released under the [MIT License](https://opensource.org/licenses/MIT).
