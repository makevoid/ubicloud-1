# frozen_string_literal: true

class Clover
  hash_branch(:project_prefix, "discount-code") do |r|
    r.web do
      authorize("Project:billing", @project.id)
      billing_path = "#{@project.path}/billing"

      r.post true do
        discount_code = r.params["discount_code"].to_s.strip.downcase
        Validation.validate_short_text(discount_code, "discount_code")

        # Check if the discount code exists
        discount = DiscountCode.where(Sequel.function(:lower, :discount_code) => discount_code).first
        unless discount
          flash["error"] = "Discount code not found."
          r.redirect billing_path
        end

        # Check if the discount code is expired
        if discount.expired?
          flash["error"] = "Discount code has expired."
          r.redirect billing_path
        end

        applied = false

        DB.transaction do
          # Ensure the project hasn't already applied the code.
          if !ProjectDiscountCode.where(project_id: @project.id, discount_code_id: discount.id).empty?
            raise Sequel::Rollback  # aborts the transaction
          end

          # Update credit
          current_credit = @project.credit || 0.0
          @project.update(credit: current_credit + discount.credit_amount.to_f)
          ProjectDiscountCode.create(
            project_id: @project.id,
            discount_code_id: discount.id
          )
          applied = true
        end

        if applied
          flash["notice"] = "Discount code successfully applied."
        else
          flash["error"] = "Discount code has already been applied to this project."
        end

        r.redirect billing_path
      end
    end
  end
end
