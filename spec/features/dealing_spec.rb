require "spec_helper"

RSpec.describe "Dealing", type: :feature do
  it "is relative to the button" do
    visit "/"
    click_on "Tell me your name"

    fill_in "user", with: "Foo"
    click_on "That's me"

    click_on "Let's go"
    click_on "Start the Game"
    community_url = current_url
    visit community_url.split("/community").first
    click_on "Want to join"
    click_on "Join"

    ["Bar", "Baz"].each do |name|
      using_session(name) do
        join_game(community_url, name)
      end
    end

    visit community_url
    expect(page).to have_selector(".player", count: 3)

    within ".player--dealer" do
      expect(page).to have_content("Foo")

      expect(page).not_to have_content("Bar")
      expect(page).not_to have_content("Baz")
    end

    advance_game

    # It's next player's turn to deal
    within ".player--dealer" do
      expect(page).to have_content("Bar")

      expect(page).not_to have_content("Foo")
      expect(page).not_to have_content("Baz")
    end

    advance_game

    # It's third player's turn to deal
    within ".player--dealer" do
      expect(page).to have_content("Baz")

      expect(page).not_to have_content("Foo")
      expect(page).not_to have_content("Bar")
    end

    advance_game

    # It's back to the first player
    within ".player--dealer" do
      expect(page).to have_content("Foo")

      expect(page).not_to have_content("Bar")
      expect(page).not_to have_content("Baz")
    end
  end

  def join_game(url, player_name)
    visit url
    fill_in "user", with: player_name
    click_on "Join"
  end

  def advance_game
    click_on "Deal Cards"
    click_on "Head to the Flop"
    3.times{ find(id: "advance").find("a").click }
  end
end
