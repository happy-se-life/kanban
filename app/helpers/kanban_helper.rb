module KanbanHelper
    def render_issue_ancestors(issue)
        s = +''
        ancestors = issue.root? ? [] : issue.ancestors.visible.to_a
        ancestors.each do |ancestor|
          s << '<div class="ancestor">' + content_tag('p', ancestor_details(ancestor, :project => (issue.project_id != ancestor.project_id), :truncate => 40 ))
        end
        s << '</div>' * (ancestors.size)
        s.html_safe
    end

    def ancestor_details(issue, options={})
        title = nil
        subject = nil
        text = options[:tracker] == false ? "##{issue.id}" : "#{issue.tracker} ##{issue.id}"
        if options[:subject] == false
            title = issue.subject.truncate(60)
        else
            subject = issue.subject
            if truncate_length = options[:truncate]
                subject = subject.truncate(truncate_length)
            end
        end
        only_path = options[:only_path].nil? ? true : options[:only_path]
        s = h("(#{text} : #{subject})")
    end
end
