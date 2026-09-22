# rails-agent Architecture

## 1. Purpose

`rails-agent` is a Ruby tool for analyzing a Rails codebase and constructing relevant context for an AI coding agent.

The core product problem is:

> Given a developer request and a Rails repository, determine what part of the system is affected and provide the AI coding agent with the smallest useful set of information needed to reason about and safely modify the code.

The product is therefore **not simply a Rails file finder** and not merely an LLM wrapper.

The central capability is **request-driven context construction**.

---

# 2. Core Pipeline

```text
Developer Request
       |
       v
Request Understanding
       |
       v
Target / Task Resolution
       |
       v
Rails Project Understanding
       |
       +-------------------+
       |                   |
       v                   v
   Model Analysis     Dependency Analysis
       |                   |
       +---------+---------+
                 |
                 v
        Impact / Reference Analysis
                 |
                 v
        Task-Aware Context Discovery
                 |
                 v
          Context Selection
                 |
                 v
          Ranking / Pruning
                 |
                 v
           File Loading
                 |
                 v
          Prompt Construction
                 |
                 v
                LLM
```

---

# 3. Architectural Layers

## 3.1 Request Understanding

Responsible for understanding what the developer is asking for.

Current component:

```text
lib/nlp/request_analyzer.rb
```

Responsibilities:

* determine action
* identify target Rails model
* resolve the target against models known to the project

The analyzer must not invent an entity that does not exist in the project.

Example:

```text
"Add a validation to User."
        |
        v
action  = :edit
entity  = "User"
```

---

## 3.2 Rule Selection

Responsible for determining the broad type of context required by the request.

Current components:

```text
lib/nlp/rule_selector.rb
lib/nlp/context_rules/
```

Current rules include:

```text
EditModelRule
DebugRule
ExplainRule
BaseRule
```

Rules currently control whether categories such as:

* primary model
* controller
* policy
* related models
* views

are included.

Current limitation:

Edit and Debug are very similar and context selection is still largely convention-based.

---

# 4. Rails Project Understanding

## 4.1 ProjectMapper

```text
lib/indexing/project_mapper.rb
```

Scans the Rails project and establishes the basic project map.

Current high-level structure:

```ruby
{
  models: ...,
  controllers: ...,
  views: ...
}
```

It is the source of truth for known Rails models during request resolution.

---

## 4.2 ProjectIndex

```text
lib/indexing/project_index.rb
```

Acts as a lazy analysis facade over the mapped project.

`ProjectIndex#model(name)` can construct structured information including:

```ruby
{
  analyzer: ...,
  dependency: ...,
  impact: ...,
  context: ...
}
```

The index caches model analysis results.

---

# 5. Static Analysis

## 5.1 ModelAnalyzer

```text
lib/analysis/model_analyzer.rb
```

Extracts structured information from model source code.

Current analysis includes:

* associations
* validations
* callbacks
* scopes
* enums
* includes
* extends

Association information is currently important to context discovery.

Other analysis is available for future structured reasoning.

---

## 5.2 DependencyAnalyzer

```text
lib/analysis/dependency_analyzer.rb
```

Determines dependencies associated with a target model.

It distinguishes:

```text
direct dependencies
transitive dependencies
```

It follows the project's association/dependency graph and handles cycles and duplicate traversal according to its current contract.

Dependency analysis is currently computed by `ProjectIndex` but has historically been underused by the request-to-prompt path.

---

## 5.3 ImpactAnalyzer

```text
lib/analysis/impact_analyzer.rb
```

Determines the potential blast radius of modifying a model.

It produces information such as:

```text
direct impact
indirect impact
score
risk level
```

Impact analysis is intended to help determine how widely a change may propagate.

It should eventually influence context construction and communicate important risk information to the LLM.

---

# 6. Context Construction

## 6.1 ContextBuilder

```text
lib/context/context_builder.rb
```

Determines candidate files associated with a target model.

Current convention-based context can include:

```text
primary model
primary controller
primary policy
related models
primary views
```

The current implementation primarily follows Rails naming conventions and model associations.

This is one of the major limitations of the current product.

For example:

```text
"Change how User's posts are serialized."
```

may require a serializer, presenter, Jbuilder view, or another consumer, but the current context builder does not reliably discover those components.

---

## 6.2 ContextEngine

```text
lib/context/context_engine.rb
```

Coordinates context construction and rules.

Conceptually:

```text
target model
     |
     v
ProjectIndex
     |
     +--> analysis
     +--> dependencies
     +--> impact
     +--> candidate context
     |
     v
ContextEngine
     |
     v
rule-based context selection
     |
     v
ranked context
```

The long-term responsibility of this layer is to decide **what information is relevant to the request**, rather than merely returning conventionally related files.

---

# 7. Context Ranking and Budgeting

## 7.1 ContextRanker

Ranks candidate files according to relevance.

Ranking determines which candidate files are preferred when the context cannot contain everything.

---

## 7.2 TokenEstimator

```text
lib/context/token_estimator.rb
```

Provides an approximate token count using a character-based heuristic.

Current approximation:

```text
approximately 4 characters / token
```

It is used for budgeting rather than exact tokenizer parity.

---

## 7.3 ContextPruner

```text
lib/context/context_pruner.rb
```

Removes lower-ranked files when the context exceeds the configured token budget.

These components are optimization infrastructure.

They should not determine **what the task means**.

---

# 8. File Loading

## FileLoader

```text
lib/context/file_loader.rb
```

Loads the selected files from disk and attaches their contents.

Input:

```ruby
[
  { path: "...", category: ... }
]
```

Output:

```ruby
[
  {
    path: "...",
    category: ...,
    content: "..."
  }
]
```

It is intentionally separated from context discovery and ranking.

---

# 9. Prompt Construction

## PromptBuilder

```text
lib/prompts/prompt_builder.rb
```

Combines the final context and request into the prompt sent to the LLM.

Current structure:

```text
Header
Instructions
Context
Task
```

---

## ContextSection

```text
lib/prompts/context_section.rb
```

Formats selected files into Markdown code blocks.

Example:

````text
## PRIMARY

File: app/models/user.rb

```ruby
...
````

````

Prompt construction should remain responsible for **communicating selected information**, not discovering it.

---

# 10. Responsibility Boundaries

The architecture should maintain these boundaries:

```text
RequestAnalyzer
    = What is the developer asking about?

ProjectMapper / ProjectIndex
    = What exists in the Rails project?

Analyzers
    = What do we know about the project/code?

Context Discovery
    = What code could be relevant to this request?

Context Selection
    = What relevant information should we actually include?

Ranking / Pruning
    = What fits within the available context budget?

FileLoader
    = Load the selected source code.

PromptBuilder
    = Communicate the selected context to the LLM.
````

A critical principle:

> **Discovery, selection, ranking, and prompt construction are different responsibilities.**

They should not gradually collapse into one component.

---

# 11. Current Request Path

The current programmatic request path is:

```text
Request
  |
  v
RequestAnalyzer
  |
  v
RuleSelector
  |
  v
ProjectMapper
  |
  v
ProjectIndex
  |
  v
ContextEngine
  |
  v
ContextRanker
  |
  v
TokenEstimator
  |
  v
ContextPruner
  |
  v
FileLoader
  |
  v
PromptBuilder
  |
  v
LLM
```

The CLI currently exposes several analysis operations separately; it is not yet a complete replacement for this request pipeline.

---

# 12. Current Product State

The system currently has:

* Rails project mapping
* project-aware model resolution
* model AST analysis
* dependency analysis
* impact analysis
* convention-based context discovery
* context ranking
* token budgeting
* file loading
* prompt construction

However, these capabilities are not yet fully integrated into a request-driven context intelligence system.

The biggest current limitation is:

> Context selection is still primarily based on Rails conventions rather than the semantics of the developer's request.

---

# 13. Target Architecture

The intended product should eventually behave like:

```text
Developer:
"Change how User's posts are serialized."

             |
             v

      Request Understanding
             |
             v

       Target = User
       Task = serialization change
             |
             v

      Project Understanding
             |
       +-----+-----+
       |     |     |
       v     v     v
     Model  Deps  References
       |     |     |
       +-----+-----+
             |
             v

      Task-Aware Discovery
             |
             v

   User model
   Post model
   serializer/presenter/etc.
   relevant controller
   relevant tests
             |
             v

       Relevance Ranking
             |
             v

        Token Budget
             |
             v

       Structured Prompt
             |
             v

             LLM
```

The key difference is that **the request drives context discovery**.

---

# 14. Design Principles

## Principle 1 — Project-aware, not guess-based

Never assume a class exists solely because its name appears in natural language.

Resolve against the actual project.

## Principle 2 — Request-driven context

The same model may require completely different context depending on the task.

For example:

```text
"Add validation to User"
```

and:

```text
"Change User serialization"
```

should not necessarily receive the same files.

## Principle 3 — Minimal sufficient context

The goal is not to dump the repository into the LLM.

The goal is:

> Give the LLM enough information to make the correct change, while avoiding irrelevant context.

## Principle 4 — Structured intelligence should not be discarded

If the system already knows:

```text
risk
impact
dependencies
associations
```

that information should have a deliberate path into context construction or the final prompt.

## Principle 5 — Analyzers remain reusable

Analyzers should produce facts.

They should not decide how those facts are formatted for a particular LLM prompt.

## Principle 6 — Small incremental checkpoints

Each major change should follow:

```text
Audit
  ↓
Contract
  ↓
Tests
  ↓
Implementation
  ↓
Targeted tests
  ↓
Full suite
  ↓
Commit
  ↓
Documentation update
```

---

# 15. Current Known Limitations

The major known limitations are:

1. Context discovery is primarily convention-based.
2. Serializer/presenter/service/job/mailers are not comprehensively discovered.
3. Reverse consumers are not consistently included in context.
4. Edit and Debug context rules are currently very similar.
5. Structured analyzer output is not yet fully integrated into prompt construction.
6. The CLI and programmatic request pipeline are separate interfaces.
7. Context ranking is based primarily on candidate categories rather than deeper task semantics.

These limitations are roadmap items, not reasons to prematurely redesign the entire architecture.

---

# 16. Architectural Direction

The project should evolve toward:

```text
Natural-language request
        ↓
Project-aware target resolution
        ↓
Task understanding
        ↓
Structured project intelligence
        ↓
Task-aware context discovery
        ↓
Context selection
        ↓
Risk/relevance ranking
        ↓
Token-budget pruning
        ↓
Structured prompt
        ↓
AI coding agent
```

The central architectural objective is:

> **Build a reliable bridge between a developer's intent and the exact portion of a Rails codebase an AI coding agent needs to understand.**
