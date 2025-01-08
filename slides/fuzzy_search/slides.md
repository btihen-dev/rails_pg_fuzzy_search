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

# open `slides/fuzzy_search/slides.md` in your editor
# or view with Slidev:
cd slides/fuzzy_search
npm run dev
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

- Trigram scoring allow for inexact matches _(mispellings, abbreviaions and missing data)_
- Trigrams are fast and effective - (expescially when indexed)

Full Article: [Rails with Postgres - Fuzzy Searches](https://btihen.dev/posts/ruby/rails_7_2_fuzzy_search/)

::right::

## Contents

<Toc text-sm minDepth="1" maxDepth="2" />

---

# PG Search Options

Postgres has a several ways to do inexact searches.

* [**Trigrams (pg_trgm)**](https://www.postgresql.org/docs/current/pgtrgm.html) - 3-character chunk matches, tolerates of mispellings & missing info
* [**Full-Text / Document Search**](https://www.postgresql.org/docs/current/textsearch.html) - similar to elastic search (but for PG)
* [**Pattern Matching**](https://www.postgresql.org/docs/current/functions-matching.html)
  - _LIKE/ILIKE_ - returns true if the string matches the supplied pattern
  - _POSIX Regular Expressions (Regex)_ - returns true if the regex pattern is matched
  - _SIMILAR TO_ - a cross between LIKE and REGEX
* [**FuzzyStrMatch**](https://www.postgresql.org/docs/current/fuzzystrmatch.html) - sounds like and distance matching
  - _Soundex_ - matching similar-sounding names (best for English)
  - _Daitch-Mokotoff Soundex_ - similar to soundex but better for non-English matching
  - _Levenshtein_ - the distance between two strings (number of edits to make them the same)
  - _Metaphone_ - like Soundex (but different algorithm)
  - _Double Metaphone_ - like Metaphone, but creates 2 pronunciations - better with non-English


---

# PG Trigram Extension (pg_trgm)

**Trigrams** are fast and efficient tool for most 'fuzzy' searches

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

# Fuzzy Search Goal

We want to find a person using a nickname, incomplete lastname and an incomplete job title

**GOAL:** find `Emilia Johnson` with the search: `Emily John, a research scientist`

Data Structure:

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

# Single Table, Single-Column

Using only the last name, is not very impressive (our target person is the 3rd result & **40% certainty**)

Use: `.where("last_name % ?", compare_string)` and `similarity(last_name, compare_string)`

```ruby
compare_string = 'Emily John, a research scientist' # []
compare_string = 'Emily John' # []
compare_string = 'John' # [John Johnson-44%, Emma Johnson-44, Emilia Johnston-40%]
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
similarity_calc = "similarity(last_name, #{compare_quoted})"

Person.select("id, last_name, first_name, #{similarity_calc} AS score")
      .where("last_name % ?", compare_string).order("score DESC")

[#<Person:0x000000010c4733f0 id: 2, last_name: "Johnson", first_name: "John", score: 0.44444445>,
 #<Person:0x0000000119138fc0 id: 6, last_name: "Johnson", first_name: "Emma", score: 0.44444445>,
 #<Person:0x0000000119138e80 id: 7, last_name: "Johnston", first_name: "Emilia", score: 0.4>]

# SQL version
SELECT id, last_name, first_name, similarity(last_name, 'John') AS score
  FROM "people" WHERE (last_name % 'John') ORDER BY score DESC
```

---

# Rails - Single Table, Multi-Column Search

First and last name - top match is our target person, but only a **42% certainty**

Use : `CONCAT_WS(' ', first_name, last_name)`

```ruby
compare_string = 'Emily John, a research scientist' # []
compare_string = 'Emily John' # [Emilia Johnson-42%, John Johnston-33%, Emma Johnson-33%]
compare_string = 'John' # [John Johnson-55%, John Smith-45%]
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
concat_fields = "CONCAT_WS(' ', first_name, last_name)"
similarity_calc = "similarity(#{concat_fields}, #{compare_quoted})"

Person.select("id, last_name, first_name, #{similarity_calc} AS score")
      .where("#{concat_fields} % #{compare_quoted}").order("score DESC")

[#<Person:0x0000000114c515d8 id: 7, last_name: "Johnston", first_name: "Emilia", score: 0.42105263>,
 #<Person:0x0000000100a85a10 id: 2, last_name: "Johnson", first_name: "John", score: 0.33333334>,
 #<Person:0x0000000100a858d0 id: 6, last_name: "Johnson", first_name: "Emma", score: 0.33333334>]

# SQL version
SELECT id, last_name, first_name, similarity(CONCAT_WS(' ', first_name, last_name), 'Emily John') AS score
  FROM "people" WHERE (CONCAT_WS(' ', first_name, last_name) % 'Emily John') ORDER BY score DESC
```

---

# Rails - Multi-Table, Multi-Column Search

Let's search across multiple tables and match against names, job titles and departments

Use: `joins(:roles)` & `CONCAT_WS(' ', first_name, last_name, job_title, department)`

```ruby
compare_string = 'Emily John, a research scientist' # [Emilia Johnson-60%]
compare_string = 'a scientist research, John Emily' # [Emilia Johnson-60%]
compare_string = 'Emily John' # []
compare_string = 'John' # []
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
concat_fields = "CONCAT_WS(' ', first_name, last_name, job_title, department)"
similarity_calc = "similarity(#{concat_fields}, #{compare_quoted})"

Person.select("people.id, last_name, first_name, job_title, department, #{similarity_calc} AS score")
      .joins(:roles).where("#{concat_fields} % #{compare_quoted}").order("score DESC")

[#<Person:0x000000012657c818
  id: 7, last_name: "Johnston", first_name: "Emilia", job_title: "Data Scientist", department: "Research", score: 0.6>]

# SQL
SELECT people.id, last_name, first_name, job_title, department,
  similarity(CONCAT_WS(' ', first_name, last_name, job_title, department), 'Emily John, a research scientist') AS score
  FROM "people" INNER JOIN "roles" ON "roles"."person_id" = "people"."id"
  WHERE (CONCAT_WS(' ', first_name, last_name, job_title, department) % 'Emily John, a research scientist')
  ORDER BY score DESC
```

We found our person - with a **60% certainty** (all other results were below 30% certainty)

---

# Custom Thresholds

instead of `where("#{concat_fields} % #{compare_quoted}")`

use format: `where("#{similarity_calc} > ?", threshold)`

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

# Best Matches & Debugging

good for auto-suggestion/dropdown suggestions (and query debugging)

Remove the `where` clause _(which reduces the query response time on a large dataset)_

```ruby
compare_string = 'John'
compare_quoted = ActiveRecord::Base.connection.quote(compare_string)
similarity_calc = "similarity(last_name, #{compare_quoted})"

Person.select("id, last_name, first_name, #{similarity_calc} AS score").order("score DESC")

[#<Person:0x0000000100ae2a80 id: 6, last_name: "Johnson", first_name: "Emma", score: 0.44444445>,
 #<Person:0x0000000100ae2940 id: 2, last_name: "Johnson", first_name: "John", score: 0.44444445>,
 #<Person:0x0000000100ae2800 id: 7, last_name: "Johnston", first_name: "Emilia", score: 0.4>,
 #<Person:0x0000000100ae26c0 id: 3, last_name: "Johanson", first_name: "Jonathan", score: 0.27272728>,
 #<Person:0x0000000100ae2580 id: 9, last_name: "Jones", first_name: "Olivia", score: 0.22222222>,
 #<Person:0x0000000100ae2440 id: 11, last_name: "Davis", first_name: "Ava", score: 0.0>,
 "..."]

# SQL version
SELECT id, last_name, first_name, similarity(last_name, 'John') AS score FROM "people" ORDER BY score DESC
```

Use `limit` to limit return the appropriate number of results

---

# Summary

An effective fuzzy search easily implemented in Rails with Postgres

**Trigrams:**
- fast and efficient (especially when indexed)
- handles human sentences (when searched over multiple columns/tables)
- effective inexact _fuzzy_ searches (mispellings, abbreviations, missing/extra data)
- Three search functions (see docs): `similarity`, `word_similarity` and `strict_word_similarity`

**Limitations:**
- not effective for pronunciation matching
- not effective for distance matching (number of changes needed to match)
- ASCII compared to similar extended ASCII characters don't match (ç compared to c, u compared to ü, ...),
  _but given the fuzzy nature of the search, this is generally not a significant limitation_

---

# Questions / Comments

Thank you for your time!

## Resources

* [pg_trgm docs](https://www.postgresql.org/docs/current/pgtrgm.html)
* [Postgres Fuzzy Search (Trigrams)](https://dev.to/moritzrieger/build-a-fuzzy-search-with-postgresql-2029)
* [Optimizing Postgres Text Search with Trigrams](https://alexklibisz.com/2022/02/18/optimizing-postgres-trigram-search)
* [Awesome Autocomplete: Trigram Search in Rails and PostgreSQL](https://www.sitepoint.com/awesome-autocomplete-trigram-search-in-rails-and-postgresql/)
