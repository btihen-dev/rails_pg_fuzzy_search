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
...]

# Insert Data
people_data.each do |person_data|
  person = Person.create(
    first_name: person_data[:first_name], last_name: person_data[:last_name], birthdate: person_data[:birthdate]
  )
  Role.create!(
    person_id: person.id, job_title: person_data[:job_title], department: person_data[:department]
  )
end
```
---

# Single Table, Single-Column Search

## SQL
```sql
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

## Rails
```ruby
compare_string = 'Johns'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
similarity_calc = "similarity(last_name, #{compare_quoted})"

Person.select("*, #{similarity_calc} AS score")
      .where("last_name % ?", compare_string)
      .order("score DESC").limit(3)
```
---

# Single Table, Multi-Column Search

use `CONCAT_WS` to build a single text from multiple db fields

```ruby
threshold = 0.2
compare_string = 'Emily Johns'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
concat_fields = "CONCAT_WS(' ', first_name, last_name)"
similarity_calc = "similarity(#{concat_fields}, #{compare_quoted})"

Person.select("*, #{similarity_calc} AS score")
      .where("#{similarity_calc} > ?", threshold)
      .order("score DESC")
      .limit(5)

# or

Person.select("*, #{similarity_calc} AS score")
      .where("#{concat_fields} % #{compare_quoted}")
      .order("score DESC")
      .limit(5)
```

---

# Multi-Table, Multi-Column Search

use a join and then include all fields using the `CONCAT_WS`

```ruby
compare_string = 'Emily, a research scientist'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
concat_fields = "CONCAT_WS(' ', first_name, last_name, job_title, department)"
similarity_calc = "similarity(#{concat_fields}, #{compare_quoted})"

Person.joins(:roles)
      .select("*, #{similarity_calc} AS score")
      .order("score DESC")
      .limit(3)

# or

Person.joins(:roles)
      .select("*, #{similarity_calc} AS score")
      .where("#{concat_fields} % #{compare_quoted}")
      .order("score DESC")
      .limit(3)
```
---

# Questions or Comments?
