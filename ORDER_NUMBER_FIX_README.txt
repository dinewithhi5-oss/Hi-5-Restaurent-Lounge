ORDER NUMBER DUPLICATE FIX
    --------------------------
    If customer orders show: duplicate key value violates unique constraint
    "food_orders_order_number_key", open Supabase Dashboard > SQL Editor,
    paste and run supabase/order_number_duplicate_fix.sql from this project.
    This updates the receipt-number trigger so it checks existing order numbers,
    catches up if the counter is behind, and allocates numbers atomically.
    Existing orders are not deleted or renumbered.
