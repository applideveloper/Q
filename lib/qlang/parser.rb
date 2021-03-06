require 'qlang/api'

require 'qlang/lexer/cont_lexer'
require 'qlang/lexer/func_lexer'

require 'qlang/parser/base'
require 'qlang/parser/matrix_parser'
require 'qlang/parser/vector_parser'
require 'qlang/parser/list_parser'
require 'qlang/parser/func_parser'
require 'qlang/parser/integral_parser'
require 'qlang/parser/formula_parser'

module Qlang
  module Parser
    def execute(lexed)
      time = Time.now
      until lexed.token_str =~ /\A(:NLIN\d|:R\d)+\z/
        fail "I'm so sorry, something wrong. Please feel free to report this." if Time.now > time + 10

        case lexed.token_str
        when /:LPRN\d(:CONT\d):RPRN\d/
          cont_token_with_num = $1
          cont_lexed = Lexer::ContLexer.new(lexed.get_value(cont_token_with_num))

          case cont_lexed.token_str
          when /(:NUM\d)+(:SCLN\d|:NLIN\d)(:NUM\d)/
            cont = MatrixParser.execute(cont_lexed)
          when /(:NUM\d)+/
            cont = VectorParser.execute(cont_lexed)
          else
            cont = "(#{cont_lexed.values.join(' ')})"
          end
          lexed.squash_with_prn(cont_token_with_num, cont)

        when /:LBRC\d(:CONT\d):RBRC\d/
          cont_token_with_num = $1
          cont_lexed = Lexer::ContLexer.new(lexed.get_value(cont_token_with_num))

          case cont_lexed.token_str
          when /(:SYM\d:CLN\d(:STR\d|:NUM\d|:R\d):CMA)*(:SYM\d:CLN\d(:STR\d|:NUM\d|:R\d))/
            cont = ListParser.execute(cont_lexed)
          else
            cont = "{#{cont_lexed.values.join(' ')}}"
          end
          lexed.squash_with_prn(cont_token_with_num, cont)

        when /:FUNC\d/
          cont_token_with_num = $&
          cont_lexed = Lexer::FuncLexer.new(lexed.get_value(cont_token_with_num))

          case cont_lexed.token_str
          when /:FDEF\d:EQL\d:FOML\d/
            cont = FuncParser.execute(cont_lexed)
            lexed.ch_value(cont_token_with_num, cont)
            lexed.ch_token(cont_token_with_num, :R)
          end

        when /:ITGL\d/
          cont_token_with_num = $&
          cont = IntegralParser.execute(lexed.get_value(cont_token_with_num))
          lexed.ch_value(cont_token_with_num, cont)
          lexed.ch_token(cont_token_with_num, :R)

        when /:EFUNC\d/
          cont_token_with_num = $&
          cont = lexed.get_value(cont_token_with_num)
          lexed.squash_with_prn(cont_token_with_num, cont)

        when /:DIFF\d/
          cont_token_with_num = $&
          cont = lexed.get_value(cont_token_with_num)
          cont =~ /(d\/d[a-zA-Z]) (.*)/
          cont = "#{$1}(#{FormulaParser.execute($2)})"
          # FIX: Refactor
          #cont.gsub!(/(d\/d[a-zA-Z]) (.*)/, "\1(\2)")
          lexed.squash_with_prn(cont_token_with_num, cont)
        when /:CONT\d/
          lexed.ch_token($&, :R)
        end

        lexed.squash_to_cont($1, 2) if lexed.token_str =~ /(:CONT\d|:R\d)(:CONT\d|:R\d)/
      end
      lexed.fix_r_txt!
      lexed.values.join
    end
    module_function :execute
  end
end
