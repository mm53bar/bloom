module ApplicationHelper
  def nav_link_to(text, path)
    classes =
      if current_page?(path)
        "font-medium text-emerald-800 underline underline-offset-4"
      else
        "text-stone-600 hover:text-emerald-800"
      end

    link_to text, path, class: classes
  end

  STATUS_STYLES = {
    "needs water" => "border-amber-300 bg-amber-50 text-amber-900",
    "too wet" => "border-sky-300 bg-sky-50 text-sky-900",
    "needs checking" => "border-stone-300 bg-stone-100 text-stone-700",
    "fine" => "border-emerald-300 bg-emerald-50 text-emerald-900"
  }.freeze

  def status_badge(status)
    tag.span status,
      class: "inline-block rounded-full border px-2.5 py-0.5 text-xs font-medium #{STATUS_STYLES.fetch(status, STATUS_STYLES['fine'])}"
  end

  # Areas with one spot read as just the area name; subdivided ones show both.
  def spot_label(spot)
    spot.full_name
  end

  def light_badge(level)
    tag.span level.humanize,
      class: "inline-block rounded border border-stone-300 bg-white px-2 py-0.5 text-xs text-stone-600"
  end

  def medium_label(medium)
    medium == "semi_hydro" ? "Semi-hydro" : "Soil"
  end

  def day_count(date)
    return "never" if date.blank?

    days = (Date.current - date).to_i
    case days
    when 0 then "today"
    when 1 then "yesterday"
    else "#{days} days ago"
    end
  end

  def button_classes(style = :primary)
    base = "inline-block rounded-md px-3 py-1.5 text-sm font-medium"

    case style
    when :primary then "#{base} bg-emerald-700 text-white hover:bg-emerald-800"
    when :secondary then "#{base} border border-stone-300 bg-white text-stone-700 hover:bg-stone-50"
    when :danger then "#{base} border border-red-300 bg-white text-red-700 hover:bg-red-50"
    end
  end
end
