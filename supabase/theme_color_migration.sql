-- Run this once in the Supabase SQL Editor to enable saved website themes.
alter table public.restaurant_settings
add column if not exists theme_color text not null default 'peach';

alter table public.restaurant_settings
drop constraint if exists restaurant_settings_theme_color_check;

alter table public.restaurant_settings
add constraint restaurant_settings_theme_color_check
check (theme_color in ('peach','green','orange','red','blue','purple','teal','pink','gold','navy'));
