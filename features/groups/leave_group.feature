Feature: Leave Group
  In order to allow users to withdraw from participating in a group
  Users must be able to leave groups

  Scenario: Group member leaves group
    Given I am logged in
    And I am a member of a group
    When I visit the group page
    And I choose to leave the group
    Then I should be removed from the group