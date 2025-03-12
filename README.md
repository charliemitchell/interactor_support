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
- **Custom RuboCop Cops** – Enforce best practices

---

## 📦 **Installation**

Add to your Gemfile:

```sh
bundle add interactor_support
```

Or install manually:

```sh
gem install interactor_support
```

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

  requires :todo_id, :title
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
  requires :todo_id
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
  requires :todo
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

#### 🔹 **`InteractorSupport::Concerns::Skippable`**

Allows an interactor to **skip execution** if a condition is met.

#### 🔹 **`InteractorSupport::Validations`**

Provides **automatic input validation** before execution.

#### 🔹 **`InteractorSupport::RequestObject`**

Provides structured, validated request objects based on **ActiveModel**.

---

## 📏 **Custom RuboCop Cops**

Enable them in `.rubocop.yml`:

```yaml
require:
  - interactor_support/rubocop
Cop/RequireRequiredForInteractorSupport:
  Enabled: true
Cop/UnusedIncludedModules:
  Enabled: true
Cop/UsedUnincludedModules:
  Enabled: true
```

`Cop/RequireRequiredForInteractorSupport` registers an offense when not invoking `required` when including InteractorSupport.
Since required both acts as documentation as to what context attributes are required for your Interactor or Organizer, and an `attr_reader` for context values.

`Cop/UnusedIncludedModules` a highly aggressive cop intended to promote lean interactors. It registers an offense when including modules that are unused in the interactor. eg: `include InteractorSupport` includes all of the concerns, and validations. However, Request Objects are ignored.

`Cop/UsedUnincludedModules` registers an offense when including Interactor, and invoking methods in InteractorSupport, but not including the correct module for it. This can give false positives if using another module that implements the same method name
as an InteractorSupport method, and intentionally not including InteractorSupport.

---

## 🤝 **Contributing**

Pull requests are welcome on [GitHub](https://github.com/charliemitchell/interactor_support).

---

## 📜 **License**

Released under the [MIT License](https://opensource.org/licenses/MIT).
