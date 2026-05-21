/// Enum values accepted by the User Management actor profile API
/// ([Backend/User_Management_Service/validators/profile.js]).
abstract final class ActorProfileOptions {
  static const List<String> genderOptions = <String>['Male', 'Female'];

  static const List<String> ethnicityOptions = <String>[
    'White',
    'Black',
    'Asian',
    'Arab',
  ];

  static const List<String> bodyTypeOptions = <String>[
    'Slim',
    'Athletic',
    'Average',
    'Heavyset',
  ];
}
