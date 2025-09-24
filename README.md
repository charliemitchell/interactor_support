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
- Gracefully ignores unknown attributes if configured, with optional logging

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

### 🔍 Ignoring Unknown Attributes

To prevent `RequestObject` from raising an error on unexpected keys, declare `ignore_unknown_attributes` in your class.

```ruby
class CalendarRequest
  include InteractorSupport::RequestObject

  ignore_unknown_attributes

  attribute :start_date, type: :date
  attribute :end_date, type: :date
  attribute :timezone, transform: :strip

  validates :start_date, :end_date, presence: true
end
```

Now, if you initialize the request with an unexpected attribute, it will be logged (if logging is enabled) and ignored:

```ruby
CalendarRequest.new(start_date: "2025-07-01", end_date: "2025-07-02", foo: "bar")
# => No exception raised; 'foo' is ignored.
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

A flexible, form-like abstraction for service object inputs, built on top of ActiveModel. InteractorSupport::RequestObject extends ActiveModel::Model and ActiveModel::Validations to provide structured, validated, and transformed input objects. It adds first-class support for nested objects, type coercion, attribute transformation, and array handling. It's ideal for use with any architecture that benefits from strong input modeling.

_RequestObject Enforces Input Integrity, and 🔐 allow-lists attributes by default_

**Features**

- Define attributes with types and transformation pipelines
- Supports primitive and custom object types
- Deeply nested input coercion and validation
- Array support for any type
- Auto-generated context hashes or structs
- Key rewriting for internal/external mapping
- Full ActiveModel validation support

Rather than manually massaging and validating hashes or params in your services, define intent-driven objects that:

- clean incoming values
- validate data structure and content
- expose clean interfaces for business logic

🚀 Getting Started

1. Define a Request Object

```rb
class GenreRequest
  include InteractorSupport::RequestObject

  attribute :title, transform: :strip
  attribute :description, transform: :strip

  validates :title, :description, presence: true
end
```

2. Use it in your Interactor, Service, or Controller

```rb
class GenresController < ApplicationController
  def create
    context = SomeOrganizerForCreatingGenres.call(
      GenreRequest.new(params.permit!) # 😉 request objects are a safe and powerful replacement for strong params
    )

    # render context.genre & handle success? vs failure?
  end
end
```

## Attribute Features

#### Transformations:

Apply one or more transformations when values are assigned.

```rb
attribute :email, transform: [:strip, :downcase]
```

- You can use any transform that the value can `respond_to?`
- Define custom transforms as instance methods.

Type Casting:
Cast inputs to expected types automatically:

```rb
attribute :age, type: :integer
attribute :tags, type: :string, array: true
attribute :config, type: Hash
attribute :published_at, type: :datetime
attribute :user, type: User
```

If the value is already of the expected type, it will just pass through. Otherwise, it will try to cast it.
If casting fails, or you specify an unsupported type, it will raise an `InteractorSupport::RequestObject::TypeError`

Supported types are

- Any ActiveModel::Type, provided as a symbol.
- The following primitives, Array, Hash, Symbol
- RequestObject subclasses (for nesting request objects)

#### Nesting Request Objects

```rb
class AuthorRequest
  include InteractorSupport::RequestObject

  attribute :name
  attribute :location, type: LocationRequest
end

class PostRequest
  include InteractorSupport::RequestObject

  attribute :authors, type: AuthorRequest, array: true
end
```

Nested objects are instantiated recursively and validated automatically.

## Rewrite Keys

Rename external keys for internal use.

```rb
attribute :image, rewrite: :image_url, transform: :strip

request = ImageUploadRequest.new(image: '  https://url.com  ')
request.image_url # => "https://url.com"
request.respond_to?(:image) # => false
```

## to_context Output

Return a nested Hash, Struct, or self:

```rb
# Default
PostRequest.new(authors: [{ name: "Ruby", location: { city: "Seattle" }}])
# returns a hash with symbol keys => {:authors=>[{:name=>"Ruby", :location=>{:city=>"Seattle"}}]}

# Configure globally
InteractorSupport.configure do |config|
  config.request_object_behavior = :returns_context # or :returns_self
  config.request_object_key_type = :symbol # or :string, :struct
end

# request_object_behavior = :returns_context, request_object_key_type = :string
PostRequest.new(authors: [{ name: "Ruby", location: { city: "Seattle" }}])
# returns a hash with string keys => {"authors"=>[{"name"=>"Ruby", "location"=>{"city"=>"Seattle"}}]}

# request_object_behavior = :returns_context, request_object_key_type = :struct
PostRequest.new(authors: [{ name: "Ruby", location: { city: "Seattle" }}])
# returns a Struct => #<struct  authors=[{:name=>"Ruby", :location=>{:city=>"Seattle"}}]>

# request_object_behavior = :returns_self, request_object_key_type = :symbol
request = PostRequest.new(authors: [{ name: "Ruby", location: { city: "Seattle" }}])
# returns the request object => #<PostRequest  authors=[{:name=>"Ruby", :location=>{:city=>"Seattle"}}]>
# request.authors.first.location.city => "Seattle"
# request.to_context => {:authors=>[{:name=>"Ruby", :location=>{:city=>"Seattle"}}]}
```

🛡 Replacing Strong Parameters Safely

InteractorSupport::RequestObject is a safe, testable, and expressive alternative to Rails’ strong_parameters. While strong_params are great for sanitizing controller input, they tend to:

- Leak into your business logic
- Lack structure and type safety
- Require repetitive permit/require declarations
- Get clumsy with nesting and arrays

Instead, RequestObject defines the expected shape and behavior of input once, and gives you:

- Input sanitization via transform:
- Validation via ActiveModel
- Type coercion (including arrays and nesting)
- Reusable, composable input classes

StrongParams Example

```rb
def user_params
  params.require(:user).permit(:name, :email, :age)
end

def create
  user = User.new(user_params)
  ...
end
```

Even with this, you still have to:
• Validate formats (like email)
• Coerce types (:age is still a string!)
• Repeat this logic elsewhere

**Request Object Equivelent**

```rb
class UserRequest
  include InteractorSupport::RequestObject

  attribute :name, transform: :strip
  attribute :email, transform: [:strip, :downcase]
  attribute :age, type: :integer # or transform: [:to_i]

  validates :name, presence: true
  validates_format_of :email, with: URI::MailTo::EMAIL_REGEXP
end
```

**Why replace Strong Params?**
| Feature | Strong Params | Request Object |
|----------------------------------|---------------------|----------------------|
| Requires manual permit/require | ✅ Yes | ❌ Not needed |
| Validates types/formats | ❌ No | ✅ Yes |
| Handles nested objects | 😬 With effort | ✅ First-class support |
| Works outside controllers | ❌ Not cleanly | ✅ Perfect for services/interactors |
| Self-documenting input shape | ❌ No | ✅ Defined via attribute DSL |
| Testable as a unit | ❌ Not directly | ✅ Easily tested like a form object |

💡 Tip

You can still use params.require(...).permit(...) in the controller if you want to restrict top-level keys, then pass that sanitized hash to your RequestObject:

```rb
UserRequest.new(params.require(:user).permit(:name, :email, :age))
```

But with RequestObject, that’s often unnecessary because you’re already defining a schema.

## InteractorSupport::Organizable

The Organizable concern provides utility methods to simplify working with interactors and request objects. It gives you a clean and consistent pattern for extracting, transforming, and preparing parameters for use in service objects or interactors.

Features

- organize: Call interactors with request objects, optionally namespaced under a context_key, and wrap validation failures in a consistent error.
- request_params: Extract, shape, filter, rename, flatten, and merge incoming params in a clear and declarative way.
- Built for controllers or service entry points.
- Rails-native feel — works seamlessly with strong params.

#### API Reference

**#organize(interactor, params:, request_object:, context_key: nil)**
Calls the given interactor with a request object built from the provided params.

| Argument       | Type          | Description                                                                 |
| -------------- | ------------- | --------------------------------------------------------------------------- |
| interactor     | Class         | The interactor to call (.call must be defined).                             |
| params         | Hash          | Parameters passed to the request object.                                    |
| request_object | Class         | A request object class that accepts params in its initializer.              |
| context_key    | Symbol or nil | Optional key to namespace the request object inside the interactor context. |

Examples

```rb
organize(MyInteractor, params: request_params, request_object: MyRequest)

# => MyInteractor.call(MyRequest.new(params))

organize(MyInteractor, params: request_params, request_object: MyRequest, context_key: :request)

# => MyInteractor.call({ request: MyRequest.new(params) })
```

Validation failures inside the request object raise `InteractorSupport::Errors::InvalidRequestObject`. The exception exposes the request class and its validation messages, making it straightforward to surface errors back to the caller.

```rb
def create
  organize(CreateUserInteractor, params: request_params(:user), request_object: CreateUserRequest)
  redirect_to dashboard_path
rescue InteractorSupport::Errors::InvalidRequestObject => e
  flash.now[:alert] = "Unable to continue: #{e.errors.to_sentence}"
  render :new, status: :unprocessable_entity
end
```

#### #request_params(\*top_level_keys, merge: {}, except: [], rewrite: [])

Returns a shaped parameter hash derived from params.permit!. You can extract specific top-level keys, rename them, flatten values, apply defaults, and remove unwanted fields.

| Argument          | Type                             | Description                                                               |
| ----------------- | -------------------------------- | ------------------------------------------------------------------------- |
| `*top_level_keys` | `Symbol...`                      | Optional list of top-level keys to include. If omitted, includes all.     |
| `merge:`          | `Hash`                           | Extra values to merge into the result.                                    |
| `except:`         | `Array<Symbol or Array<Symbol>>` | Keys or nested key paths to exclude.                                      |
| `rewrite:`        | `Array<Hash>`                    | Rules for renaming, flattening, filtering, merging, or defaulting values. |

Rewrite Options

Each rewrite entry is a hash in the form { key => options }, where options may include:
| Option | Type | Description |
|-----------|---------------------------|-------------------------------------------------------------------|
| `as` | `Symbol` | Rename the key to a new top-level key. |
| `only` | `Array<Symbol>` | Include only these subkeys in the result. |
| `except` | `Array<Symbol>` | Remove these subkeys from the result. |
| `flatten` | `true` or `Array<Symbol>` | Flatten all subkeys into top-level (or just the specified ones). |
| `default` | `Hash` | Use this value if the original key is missing or nil. |
| `merge` | `Hash` | Merge this hash into the result (after filtering and flattening). |

Example: full usage

```rb
# Incoming params:
params = {
  order: {
    product_id: 1,
    quantity: 2,
    internal: "should be removed"
  },
  metadata: {
    source: "mobile",
    internal: "hidden",
    location: { ip: "1.2.3.4" }
  },
  flags: {
    foo: true
  },
  internal: "global_internal",
  session: nil
}

# Incantation:
request_params(:order, :metadata, :flags, :session,
  merge: { user: current_user }, # <- Add the user
  except: [[:order, :internal], :internal], # <- remove `order.internal`, and the top level key `internal`
  rewrite: [
    { order: { flatten: true } }, # <- moves all the values from order to top level keys
    { metadata: { as: :meta, only: [:source, :location], flatten: [:location] } }, # <- Rename metadata to meta, pluck source and location, move location's values to meta
    { flags: { merge: { debug: true } } }, # <- add flags.debug = true
    { session: { default: { id: nil } } } # <- create a default value for session
  ]
)

# Result
{
  product_id: 1,
  quantity: 2,
  meta: {
    source: "mobile",
    ip: "1.2.3.4"
  },
  flags: {
    foo: true,
    debug: true
  },
  session: {
    id: nil
  },
  user: current_user
}
```

⚠️ Array flattening is not supported

Flattening arrays of hashes (e.g., { events: [{ id: 1 }] }) is intentionally not supported to avoid accidental key collisions. If needed, transform such structures manually before passing to request_params.

**Usage**

Include in a controller or service base class

```rb
class ApplicationController < ActionController::Base
  include InteractorSupport::Concerns::Organizable
end
```

---

## 🛠 Configuration Reference

All global settings for InteractorSupport can be set via the `InteractorSupport.configure` block. Here's a full list of configuration options:

<!-- prettier-ignore-start -->
| Key | Type | Default | Description |
| --- | ---- | ------- | -----------|
| `logger` | `Logger` | `Logger.new($stdout)` | Logger instance used for internal logging. |
| `log_level` | `Integer` (Logger constant) | `Logger::INFO` | Logging level (e.g., `Logger::DEBUG`, `Logger::WARN`, etc.). |
| `log_unknown_request_object_attributes` | `Boolean` | `true` | Whether to log unknown request attributes that are ignored. |
| `request_object_behavior` | `Symbol` | `:returns_context` | Controls what `RequestObject.new(...)` returns (`:returns_self` or `:returns_context`). |
| `request_object_key_type` | `Symbol` | `:symbol` | Controls the output format of keys in `#to_context` (`:symbol`, `:string`, `:struct`).  |
<!-- prettier-ignore-end -->

To update these settings, use:

```ruby
InteractorSupport.configure do |config|
  config.logger = Rails.logger
  config.log_level = Logger::WARN
  config.log_unknown_request_object_attributes = true
  config.request_object_behavior = :returns_self
  config.request_object_key_type = :struct
end
```

## 🤝 **Contributing**

Pull requests are welcome on [GitHub](https://github.com/charliemitchell/interactor_support).

---

## 📜 **License**

Released under the [MIT License](https://opensource.org/licenses/MIT).
