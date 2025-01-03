---
# You can also start simply with 'default'
theme: seriph
# random image from a curated Unsplash collection by Anthony
# like them? see https://unsplash.com/collections/94734566/slidev
background:
# https://unsplash.com/photos/man-standing-near-glass-window-ER6_i8FhQIw
# https://unsplash.com/photos/PFxSKx4kc5U
# some information about your slides (markdown enabled)
title: Postgres - Fuzzy Searches
info: |
  ## Slidev Starter Template
  Presentation slides for developers.

  Learn more at [Sli.dev](https://sli.dev)
# apply unocss classes to the current slide
class: text-center
# https://sli.dev/features/drawing
drawings:
  persist: false
# slide transition: https://sli.dev/guide/animations.html#slide-transitions
transition: slide-left
# enable MDC Syntax: https://sli.dev/features/mdc
mdc: true
---

# Postgres - Fuzzy Searches

Similarity Searches with Postgres <br> (inexact data matching)

## by Bill Tihen

To follow along:

```bash
git clone https://github.com/btihen-dev/rails_pg_fuzzy_search
cd rails_pg_fuzzy_search
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed

# code examples at:
# slides/fuzzy_search/slides.md
# https://btihen.dev/posts/ruby/rails_7_2_fuzzy_search/
```

<div class="abs-br m-6 text-xl">
  <button @click="$slidev.nav.openInEditor" title="Open in Editor" class="slidev-icon-btn">
    <carbon:edit />
  </button>
  <a href="https://github.com/slidevjs/slidev" target="_blank" class="slidev-icon-btn">
    <carbon:logo-github />
  </a>
</div>

---
layout: two-cols
layoutClass: gap-8
---

# Introduction

We required finding a record with incomplete information (across multiple columns and tables)

- `LIKE` and `ILIKE` requires precision.
- Trigram scoring allow for inexact matches _(mispellings, abbreviaions and missing data)_
- Trigrams are fast and effective **fuzzy** searches

Full Article: [Rails with Postgres - Fuzzy Searches](https://btihen.dev/posts/ruby/rails_7_2_fuzzy_search/)

::right::

## Contents

<Toc text-sm minDepth="1" maxDepth="2" />

---

# Fuzzy Search Options

Postgres has a several ways to do inexact searches.

1. LIKE / ILIKE (contains)
2. Trigram Indexes (pg_trgm) - estimates similary of sets of three characters
3. Phonetic Algorithms - (FuzzyStrMatch, metaphone, soundex) - matches as if read aloud
4. Distance Algorithms - (levenshtein) edits required to transform into a match

**Trigrams** are fast and efficient tool for most general fuzzy searches

---

# PG Trigram Extension (pg_trgm)

pg_trgm extension is required


## Rails
```ruby
class AddTrigramExtension < ActiveRecord::Migration[7.2]
  def change
    enable_extension 'pg_trgm'
  end
end
```

## SQL
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

---

# Data Context

the data structure:

```ruby
bin/rails generate model Person last_name:string:index first_name:string:index
bin/rails generate model Role job_title:string department:string person:references

# data with similar mames but different roles
people_data = [
  { last_name: "Smith", first_name: "John", job_title: "Software Engineer",  department: "Product" },
  { last_name: "Johnson", first_name: "John", job_title: "Network Engineer", department: "Operations" },
  ...
]

# Insert Data
people_data.each do |person_data|
  person = Person.create(first_name: person_data[:first_name], last_name: person_data[:last_name])
  Role.create!(person_id: person.id, job_title: person_data[:job_title], department: person_data[:department])
end
```

**GOAL:** to find expected person with a search like: `Emily John, a research scientist`

---

# Single Table, Single-Column

Default Threshold (cutoff) score is `0.3`

```ruby
compare_string = 'John'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
similarity_calc = "similarity(last_name, #{compare_quoted})"

Person.select("id, last_name, first_name, #{similarity_calc} AS score")
      .where("last_name % ?", compare_string).order("score DESC")

[#<Person:0x000000010c4733f0 id: 2, last_name: "Johnson", first_name: "John", score: 0.44444445>,
 #<Person:0x0000000119138fc0 id: 6, last_name: "Johnson", first_name: "Emma", score: 0.44444445>,
 #<Person:0x0000000119138e80 id: 7, last_name: "Johnston", first_name: "Emilia", score: 0.4>]

# SQL version
SELECT id, last_name, first_name, similarity(last_name, 'Johns') AS score
  FROM "people" WHERE (last_name % 'Johns') ORDER BY score DESC

 id | last_name | first_name |   score
----+-----------+------------+-----------
  2 | Johnson   | John       | 0.44444445
  6 | Johnson   | Emma       | 0.44444445
  7 | Johnston  | Emilia     |       0.4
```

---

# Rails - Single Table, Multi-Column Search

use **CONCAT_WS** to build a single text from multiple db fields,

i.e.: `CONCAT_WS(' ', first_name, last_name)`

```ruby
compare_string = 'Emily Johns'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
concat_fields = "CONCAT_WS(' ', first_name, last_name)"
similarity_calc = "similarity(#{concat_fields}, #{compare_quoted})"

Person.select("id, last_name, first_name, #{similarity_calc} AS score")
      .where("#{concat_fields} % #{compare_quoted}").order("score DESC")

# we asked for 5 but only 4 matched (because the default threshold is 0.3)
[#<Person:0x00000001014cba60 id: 7, last_name: "Johnston", first_name: "Emilia", score: 0.47368422>,
 #<Person:0x00000001014cb920 id: 6, last_name: "Johnson", first_name: "Emma", score: 0.3888889>,
 #<Person:0x00000001014cb7e0 id: 2, last_name: "Johnson", first_name: "John", score: 0.3125>]

# SQL version
SELECT id, last_name, first_name, similarity(CONCAT_WS(' ', first_name, last_name), 'Emi John') AS score
  FROM "people" WHERE (CONCAT_WS(' ', first_name, last_name) % 'Emi John') ORDER BY score DESC
```

---

# Rails - Multi-Table, Multi-Column Search

Use: `joins(:roles)` & `CONCAT_WS(' ', first_name, last_name, job_title, department)`

```ruby
compare_string = 'Emily, a research scientist'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
concat_fields = "CONCAT_WS(' ', first_name, last_name, job_title, department)"
similarity_calc = "similarity(#{concat_fields}, #{compare_quoted})"

# with two tables (if we want an accurate id, we need to select which table id we want)
Person.select("people.id, last_name, first_name, job_title, department, #{similarity_calc} AS score")
      .joins(:roles).where("#{concat_fields} % #{compare_quoted}").order("score DESC")

# we asked for 3 but only 2 matched (because the default threshold is 0.3)
[#<Person:0x000000012657c818
  id: 7, last_name: "Johnston", first_name: "Emilia", job_title: "Data Scientist", department: "Research", score: 0.52272725>]

# SQL
SELECT people.id, last_name, first_name, job_title, department,
  similarity(CONCAT_WS(' ', first_name, last_name, job_title, department), 'Emily, a research scientist') AS score
  FROM "people" INNER JOIN "roles" ON "roles"."person_id" = "people"."id"
  WHERE (CONCAT_WS(' ', first_name, last_name, job_title, department) % 'Emily, a research scientist')
  ORDER BY score DESC
```

---

# Custom Thresholds

instead of `where("#{concat_fields} % #{compare_quoted}")`

use `where("#{similarity_calc} > ?", threshold)`

```ruby
threshold = 0.2
compare_string = 'John'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
similarity_calc = "similarity(last_name, #{compare_quoted})"

Person.select("id, last_name, first_name, #{similarity_calc} AS score")
      .where("#{similarity_calc} > ?", threshold).order("score DESC")

[#<Person:0x00000001240e2d18 id: 2, last_name: "Johnson", first_name: "John", score: 0.44444445>,
 #<Person:0x00000001240e2bd8 id: 6, last_name: "Johnson", first_name: "Emma", score: 0.44444445>,
 #<Person:0x00000001240e2a98 id: 7, last_name: "Johnston", first_name: "Emilia", score: 0.4>,
 #<Person:0x00000001240e2958 id: 3, last_name: "Johanson", first_name: "Jonathan", score: 0.27272728>,
 #<Person:0x00000001240e2818 id: 9, last_name: "Jones", first_name: "Olivia", score: 0.22222222>]

# SQL version
SELECT id, last_name, first_name, similarity(last_name, 'John') AS score
  FROM "people" WHERE (similarity(last_name, 'John') > 0.2) ORDER BY score DESC
```
---

# Best Matches

dropdown suggestions: drop `where` **add** `limit` the _ordered_ results (for best match: `limit 1`)

```ruby
compare_string = 'John'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
similarity_calc = "similarity(last_name, #{compare_quoted})"

Person.select("id, last_name, first_name, #{similarity_calc} AS score")
      .order("score DESC").limit(3)

[#<Person:0x000000010c4733f0 id: 2, last_name: "Johnson", first_name: "John", score: 0.44444445>,
 #<Person:0x0000000119138fc0 id: 6, last_name: "Johnson", first_name: "Emma", score: 0.44444445>,
 #<Person:0x0000000119138e80 id: 7, last_name: "Johnston", first_name: "Emilia", score: 0.4>]

# SQL version
SELECT id, last_name, first_name, similarity(last_name, 'Johns') AS score
  FROM "people" ORDER BY score DESC LIMIT 3
```

---

# Summary

An effective fuzzy search easily implemented in Rails with Postgres

**Trigrams:**
- are fast and efficient
- are very effective for inexact searches
- handle mispellings, abbreviations and missing data
- handle human sentences (when concatenated over multiple columns and/or tables)

**Limitations:**
- not effective with pronunciation matching
- not effective with distance (number of changes needed to match) searches

**Additional Resources**
- [Optimizing Postgres Text Search with Trigrams](https://alexklibisz.com/2022/02/18/optimizing-postgres-trigram-search)

---

# Questions / Discussion
