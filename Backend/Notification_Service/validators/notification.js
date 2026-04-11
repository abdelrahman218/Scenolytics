const checkRequiredFields = (fields) => {
  return (req, res, next) => {
    const missingFields = fields.filter((field) => !req.body[field]);
    if (missingFields.length > 0) {
      return res
        .status(400)
        .json({
          message: `Missing required fields: ${missingFields.join(", ")}`,
        });
    }
    next();
  };
};

export const validateUpdateNotificationPreferenceRequiredData =
  checkRequiredFields([
    "in_app_submission_notifications",
    "in_app_invitation_notifications",
    "email_submission_notifications",
    "email_invitation_notifications",
  ]);

const checkValidValues = (fieldsValues) => {
  return (req, res, next) => {
    Object.entries(fieldsValues).forEach(([field, values]) => {
      if (!values.includes(req.body[field]) && req.body[field]) {
        return res
          .status(400)
          .json({ message: `Invalid value for ${field}: ${req.body[field]}` });
      }
    });
    next();
  };
};

export const validateUpdateNotificationDataValues = checkValidValues({
  email_notifications: ["true", "false", "0", "1"],
  in_app_notifications: ["true", "false", "0", "1"],
  submission_notifications: ["true", "false", "0", "1"],
  invitation_notifications: ["true", "false", "0", "1"],
});
