module MigrationComments
  module AnnotateModels
    def self.prepended(base)
      class << base
        prepend ClassMethods
      end
    end

    module ClassMethods
      def get_schema_info(*args)
        klass = args[0]
        klass.reset_column_information
        info = super(*args)
        commented_info(klass, info)
      end

      def commented_info(klass, info)
        table_name = klass.table_name
        adapter = klass.connection
        table_comment = adapter.retrieve_table_comment(table_name)
        column_comments = adapter.retrieve_column_comments(table_name)
        lines = []
        info.each_line{|l| lines << l.chomp}
        column_regex = /^#\s+(\w+)\s+:\w+/
        len = lines.select{|l| l =~ column_regex}.map{|l| l.length}.max
        lines.each do |line|
          if line =~ /# Table name: |# table \+\w+\+ /
            if table_comment
              first, *rest = table_comment.split("\n")

              if rest.empty?
                line << " " * (len - line.length) << " # #{first}".rstrip
              else
                line << "\n#   #{first}".rstrip
              end

              rest.each do |comment_line|
                line << "\n#   #{comment_line}".rstrip
              end
            end
          elsif line =~ column_regex
            comment = column_comments[$1.to_sym]
            if comment
              first, *rest = comment.split("\n")

              line << " " * (len - line.length) << " # #{first}".rstrip
              rest.each do |comment_line|
                line << "\n" << "#".ljust(len) << " # #{comment_line}".rstrip
              end
            end
          end
        end
        lines.join($/) + $/
      end
    end
  end
end