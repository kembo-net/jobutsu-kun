@game = Object.new
class << @game
  class GameError < RuntimeError
  end
  class GameClear < GameError
  end
  class GameOver < GameError
  end
  class Card
    attr_reader :cost
    def initialize(name, cost = 0, text = "")
      @name = name
      @cost = cost
      @text = text
    end
    def to_s
      @name + '(' + @cost.to_s + ') ' + @text
    end
    def use(game)
      puts 'このカードは使用出来ません'
      raise GameError
    end
    def throw(game)
      unless index = game.hand.find_index(self)
        puts '手札に存在しないカードです'
        raise GameError
      end
      if game.d_point < 1
        puts 'これ以上捨てることは出来ません'
        raise GameError
      else
        game.d_point -= 1
      end
      if game.t_point < @cost
        puts '徳が足りません'
        raise GameError
      else
        game.t_point -= @cost
      end
      game.hand.delete_at(index)
      game.higan.push(self)
    end
  end
  class AbstractActionCard < Card
    def use(game)
      unless index = game.hand.find_index(self)
        puts '手札に存在しないカードです'
        raise GameError
      end
      game.hand.delete(self)
      game.dump.push(self)
      action(game)
    end
  end
  class ActionCard < AbstractActionCard
  end
  class ReactionCard < Card
    def throw(game)
      super
      reaction(game)
    end
  end
  class TokuCard < AbstractActionCard
    @@COST_LIST = {1 => 0, 2 => 3, 3 => 6}
    def initialize(num)
      @point = num.to_i
      super("徳カード" + num.to_s, @@COST_LIST[num.to_i])
    end
    def action(game)
      game.t_point += @point
    end
  end
  class InnCard < ActionCard
    def initialize
      super("因", 4, "ドロー3枚　手札を3枚まで山に戻せる")
    end
    def action(game)
      game.draw_hand(3)
      limit = game.hand.length - 3
      while game.hand.length > limit
        card = game.choose_card(
          "戻したいカードを番号で選んでください" +
          "(戻さない場合は何も入力せずにEnter)")
        if card.nil?
          break
        else
          game.deck.unshift(card)
          game.hand.delete(card)
        end
      end
    end
  end
  class EnnCard < ActionCard
    def initialize()
      super("縁", 2, "使用・破棄時にアクション・リアクションカードの能力のみを手札からコピーする")
    end
    def action(game)
      card = game.choose_card(
        "コピーしたいアクションカードを番号で選んでください" +
        "(コピーしない場合は何も入力せずにEnter)") { |card|
          card.kind_of?(ActionCard)
        }
      card.action(game) unless card.nil?
    end
    def throw(game)
      super
      reaction(game)
    end
    def reaction(game)
      card = game.choose_card(
        "コピーしたいリアクションカードを番号で選んでください" +
        "(コピーしない場合は何も入力せずにEnter)") { |card|
          card.kind_of?(ReactionCard)
        }
      card.reaction(game) unless card.nil?
    end
  end
  class ResignCard < ActionCard
    def initialize
      super("諦め", 2, "コスト4以下のカードを破棄する")
    end
    def action(game)
      card = game.choose_card(
        "破棄するカードを番号で選んでください") {|card|
          card.cost <= 4
        }
      game.higan.push(card)
      game.hand.delete(card)
      if card.kind_of?(ReactionCard) || card.kind_of?(EnnCard)
        card.reaction(game)
      end
    end
  end
  class SenseCard < ActionCard
    def initialize
      super("気づき", 0, "廃棄権 +1")
    end
    def action(game)
      game.d_point += 1
    end
  end
  class ForgivenCard < ReactionCard
    def initialize
      super("赦し", 1, "(R)このカードを破棄するとき、徳 +3")
    end
    def reaction(game)
      game.t_point += 3
    end
  end
  class SatoriCard < ReactionCard
    def initialize
      super("悟り", 2, "(R)このカードを破棄するとき、コスト5以下のカードを一枚破棄する")
    end
    def reaction(game)
      card = game.choose_card(
        "破棄するカードを番号で選んでください") {|card|
          card.cost <= 5
        }
      game.higan.push(card)
      game.hand.delete(card)
      if card.kind_of?(ReactionCard) || card.kind_of?(EnnCard)
        card.reaction(game)
      end
    end
  end
  class YokuCard < Card
  end
  class ShokuYokuCard < YokuCard
    def initialize
      super("食欲", 2)
    end
  end
  class ZaiYokuCard < YokuCard
    def initialize
      super("財欲", 5)
    end
  end
  class ShikiYokuCard < YokuCard
    def initialize
      super("色欲", 8)
    end
  end
  attr_accessor :deck, :hand, :dump, :higan, :t_point, :d_point
  def reset
    @HAND_VAL = 5
    @deck = (Array.new(6).map{TokuCard.new(1)} +
             Array.new(4).map{TokuCard.new(2)} +
             Array.new(2).map{TokuCard.new(3)} +
             Array.new(2).map{InnCard.new    } +
             Array.new(2).map{EnnCard.new    } +
             Array.new(2).map{ResignCard.new } +
             Array.new(2).map{SenseCard.new  } +
             Array.new(2).map{ForgivenCard.new}+
             Array.new(2).map{SatoriCard.new } +
             Array.new(3).map{ShokuYokuCard.new}+
             Array.new(2).map{ZaiYokuCard.new} +
             Array.new(1).map{ShikiYokuCard.new}).shuffle
    @hand = []; @dump = []; @higan = []; @s_higan = []
    @t_point = 0; @d_point = 1
  end
  def play
    reset
    result = nil
    loop do
      begin
        draw_hand(@HAND_VAL)
        turn_play
        hand_throw
        if (@hand.length + @dump.length + @deck.length) == 0
          raise GameClear
        end
      rescue GameClear
        puts "見事成仏出来ました！やったね！"
        result = :win
        break
      rescue GameOver
        puts "成仏出来ませんでした"
        result = :lose
        break
      end
    end
    return result
  end
  def hand_throw
    @dump.push(*@hand)
    @hand = []
    @t_point = 0
    @d_point = 1
  end
  def puts_hand
    @hand.each.with_index(1) do |card, num|
      puts num.to_s + '. ' + card.to_s
    end
  end
  def catch_opr
    puts_hand
    puts "徳:#{@t_point} 残り捨て回数:#{@d_point}回"
    puts "山札:#{@deck.length}枚 捨て札:#{@dump.length}枚 彼岸:#{@higan.length}枚"
    puts 'u[番号]カードを使う/t[番号]カードを捨てる/e手番を終える/qゲームを終了する'
    print '> '
    return STDIN.gets
  end
  def turn_play
    while @hand.length > 0
      case catch_opr
      when /^u(.*)/
        num = $1.to_i - 1
        if (0...@hand.length).include?(num)
          begin
            @hand[num].use(self)
          rescue GameError
          end
        else
          puts "無効なコマンドです"
        end
      when /^t(.*)/
        num = $1.to_i - 1
        if (0...@hand.length).include?(num)
          begin
            @hand[num].throw(self)
          rescue GameError
          end
        else
          puts "無効なコマンドです"
        end
      when /^e/
        break
      when /^q/
        raise GameOver
      else
        puts "無効なコマンドです"
      end
    end
  end
  def over_Sanzu
    if @higan.length >= 2
      @s_higan.push( *(@higan.shift(2)) )
      return true
    else
      return false
    end
  end
  def draw_hand(val)
    if @deck.length < val
      if over_Sanzu
        @deck.push( *(@dump.shuffle) )
        @dump = []
      else
        puts "三途の川を渡れませんでした"
        raise GameOver
      end
    end
    @hand.push( *(@deck.shift(val)) )
  end
  def choose_card(message, &condition)
    puts_hand
    puts message
    loop do
      print "> "
      num = STDIN.gets.to_i - 1
      if num < 0
        return nil
      elsif (0...@hand.length).include?(num)
        card = @hand[num]
        if ( not block_given? ) || ( yield(card) )
          return card
        else
          puts "そのカードは選択できません"
        end
      else
        puts "無効な入力です"
      end
    end
  end
end
