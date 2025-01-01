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

Full Article at [btihen.dev](https://btihen.dev/posts/ruby/rails_7_2_fuzzy_search/)

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

Code Repo to follow along: [rails_pg_fuzzy_search](https://github.com/btihen-dev/rails_pg_fuzzy_search)

::right::

## Contents

<Toc text-sm minDepth="1" maxDepth="2" />

---

# Fuzzy Search Options

Postgres has a several ways to do inexact searches

1. LIKE / ILIKE (contains)
2. Trigram Indexes (pg_trgm) - estimates similary of sets of three characters
3. Phonetic Algorithms - (FuzzyStrMatch, metaphone, soundex) - matches as if read aloud
4. Distance Algorithms - (levenshtein) edits required to transform into a match

**Trigrams** are fast and efficient tool for most general fuzzy searches

---

# Trigram Setup

pg_trgm extension is required

## SQL
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

## Rails
```ruby
class AddTrigramExtension < ActiveRecord::Migration[7.2]
  def change
    enable_extension 'pg_trgm'
  end
end
```

---

# Data Context

the data structure to search

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
---

# Single Table, Single-Column Search (SQL)
```sql
bin/rails db

SELECT id, last_name, first_name, similarity(last_name, 'Johns') AS score
  FROM people
  WHERE similarity(last_name, 'Johns') > 0.3
  ORDER BY score DESC;

 id | last_name | first_name |  score
---+---------+---------+---------
 2  | Johnson   | John      | 0.5555556
 6  | Johnson   | Emma      | 0.5555556
 7  | Johnston  | Emilia    |       0.5
```

Interesting and helpful, but we can still do better with multiple columns

---

# Single Table, Single-Column Search (Rails)
```ruby
bin/rails c

compare_string = 'Johns'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
similarity_calc = "similarity(last_name, #{compare_quoted})"

Person.select("last_name, first_name, #{similarity_calc} AS score")
      .where("last_name % ?", compare_string).order("score DESC").limit(3)

[#<Person:0x000000010c4733f0 id: 2, last_name: "Johnson", first_name: "John", score: 0.5555556>,
 #<Person:0x0000000119138fc0 id: 6, last_name: "Johnson", first_name: "Emma", score: 0.5555556>,
 #<Person:0x0000000119138e80 id: 7, last_name: "Johnston", first_name: "Emilia", score: 0.5>]

# SQL version
SELECT last_name, first_name, similarity(last_name, 'Johns') AS score
  FROM "people" WHERE (last_name % $1) /* loading for pp */
  ORDER BY score DESC LIMIT $2  [[nil, "Johns"], ["LIMIT", 3]]
```
---

# Single Table, Multi-Column Search

use `CONCAT_WS` to build a single text from multiple db fields

```ruby
compare_string = 'Emi John'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
concat_fields = "CONCAT_WS(' ', first_name, last_name)"
similarity_calc = "similarity(#{concat_fields}, #{compare_quoted})"

Person.select("last_name, first_name, #{similarity_calc} AS score")
      .where("#{concat_fields} % #{compare_quoted}").order("score DESC").limit(5)

# we asked for 5 but only 4 matched (because the default threshold is 0.3)
[#<Person:0x000000011ab51e20 last_name: "Johnston", first_name: "Emilia", score: 0.3888889, id: nil>,
 #<Person:0x000000011ab51ce0 last_name: "Johnson", first_name: "John", score: 0.3846154, id: nil>,
 #<Person:0x000000011ab51ba0 last_name: "Johnson", first_name: "Emma", score: 0.375, id: nil>,
 #<Person:0x000000011ab51a60 last_name: "Smith", first_name: "John", score: 0.33333334, id: nil>]

# SQL version
SELECT last_name, first_name, similarity(CONCAT_WS(' ', first_name, last_name), 'Emi John') AS score
  FROM "people" WHERE (CONCAT_WS(' ', first_name, last_name) % 'Emi John') /* loading for pp */
  ORDER BY score DESC LIMIT $1  [["LIMIT", 5]]
```

---

# Multi-Table, Multi-Column Search

use a join and then include all fields using the `CONCAT_WS`

```ruby
compare_string = 'Emily, a research scientist'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
concat_fields = "CONCAT_WS(' ', first_name, last_name, job_title, department)"
similarity_calc = "similarity(#{concat_fields}, #{compare_quoted})"

# with two tables (if we want an accurate id, we need to select which table id we want)
Person.select("person_id, last_name, first_name, job_title, department, #{similarity_calc} AS score")
      .joins(:roles).where("#{concat_fields} % #{compare_quoted}").order("score DESC").limit(3)

# we asked for 3 but only 2 matched (because the default threshold is 0.3)
[#<Person:0x000000011a977e60 person_id: 7, last_name: "Johnston", first_name: "Emilia",
  job_title: "Data Scientist", department: "Research", score: 0.52272725, id: nil>,
 #<Person:0x000000011a977d20 person_id: 6, last_name: "Johnson", first_name: "Emma",
   job_title: "Data Scientist", department: "Research", score: 0.4883721, id: nil>]

# SQL version
SELECT person_id, last_name, first_name, job_title, department,
  similarity(CONCAT_WS(' ', first_name, last_name, job_title, department), 'Emily, a research scientist') AS score
  FROM "people" INNER JOIN "roles" ON "roles"."person_id" = "people"."id"
  WHERE (CONCAT_WS(' ', first_name, last_name, job_title, department) % 'Emily, a research scientist') /* loading for pp */
  ORDER BY score DESC LIMIT $1  [["LIMIT", 3]]
```

---

# Custom Threshhold

Change the threshold for a match, using `where("#{similarity_calc} > ?", threshold)`

```ruby
threshold = 0.5
compare_string = 'Emily, a research scientist'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
concat_fields = "CONCAT_WS(' ', first_name, last_name, job_title, department)"
similarity_calc = "similarity(#{concat_fields}, #{compare_quoted})"

Person.select("person_id, last_name, first_name, job_title, department, #{similarity_calc} AS score")
      .joins(:roles).where("#{similarity_calc} > ?", threshold).order("score DESC")

[#<Person:0x000000011ab92948 person_id: 7, last_name: "Johnston", first_name: "Emilia",
  job_title: "Data Scientist", department: "Research", score: 0.52272725, id: nil>]

# SQL version
SELECT person_id, last_name, first_name, job_title, department,
  similarity(CONCAT_WS(' ', first_name, last_name, job_title, department), 'Emily, a research scientist') AS score
  FROM "people" INNER JOIN "roles" ON "roles"."person_id" = "people"."id"
  WHERE (similarity(CONCAT_WS(' ', first_name, last_name, job_title, department), 'Emily, a research scientist') > $1) /* loading for pp */
  ORDER BY score DESC LIMIT $2  [[nil, 0.5], ["LIMIT", 11]]
```

---

## Simplification

If you know how many top matches you want you can use `order` and `limit` instead of `where`

```ruby
compare_string = 'Emily, a research scientist'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
concat_fields = "CONCAT_WS(' ', first_name, last_name, job_title, department)"
similarity_calc = "similarity(#{concat_fields}, #{compare_quoted})"

Person.select("*, #{similarity_calc} AS score").joins(:roles).order("score DESC").limit(1)

[#<Person:0x000000011a97dae0
  id: 7,
  last_name: "Johnston",
  first_name: "Emilia",
  birthdate: "1966-01-01",
  created_at: "2024-10-31 18:30:08.788015000 +0000",
  updated_at: "2024-10-31 18:30:08.788015000 +0000",
  job_title: "Data Scientist",
  department: "Research",
  person_id: 7,
  score: 0.52272725>]

# SQL version
SELECT *, similarity(CONCAT_WS(' ', first_name, last_name, job_title, department), 'Emily, a research scientist') AS score
  FROM "people" INNER JOIN "roles" ON "roles"."person_id" = "people"."id" /* loading for pp */
  ORDER BY score DESC LIMIT $1  [["LIMIT", 1]]
```
---

# Questions or Comments?
