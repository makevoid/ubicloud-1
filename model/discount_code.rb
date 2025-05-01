# frozen_string_literal: true

require "sequel"

class DiscountCode < Sequel::Model
  include ResourceMethods

  def expired?
    Time.now > expires_at
  end
end

# Table: discount_code
# Columns:
#  id            | uuid                     | PRIMARY KEY
#  created_at    | timestamp with time zone | NOT NULL DEFAULT CURRENT_TIMESTAMP
#  discount_code | text                     | NOT NULL
#  credit_amount | numeric                  | NOT NULL
#  expires_at    | timestamp with time zone | NOT NULL
# Indexes:
#  discount_code_pkey              | PRIMARY KEY btree (id)
#  discount_code_discount_code_key | UNIQUE btree (discount_code)
# Referenced By:
#  project_discount_code | project_discount_code_discount_code_id_fkey | (discount_code_id) REFERENCES discount_code(id)
