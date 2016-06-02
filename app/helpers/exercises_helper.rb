module ExercisesHelper
  def result_table_heading(text, options = {})
    sort_html = "<span class='glyphicon glyphicon-chevron-down' aria-hidden='true'></span>".html_safe
    html = "<th>\n#{text}\n"
    html << link_to(sort_html, exercise_results_path(@exercise, :sort => options[:sort], :include => params[:include]))
    html << "\n</th>\n"
    html.html_safe
  end
end
