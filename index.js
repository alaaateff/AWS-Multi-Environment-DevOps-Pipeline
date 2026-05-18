const AWS = require("aws-sdk");
const region = process.env.region;
const ses = new AWS.SES({ region: region});

exports.handler = async (event) => {

    const params = {
        Source: "alaaatef3200@gmail.com",
        Destination: {
            ToAddresses: ["alaaatef3200@gmail.com"]
        },
        Message: {
            Subject: {
                Data: "Terraform State Changed"
            },
            Body: {
                Text: {
                    Data: "This email was sent from AWS Lambda using SES."
                }
            }
        }
    };

    try {
        const result = await ses.sendEmail(params).promise();
        console.log("Email sent:", result);

        return {
            statusCode: 200,
            body: "Email sent successfully"
        };

    } catch (error) {
        console.error(error);

        return {
            statusCode: 500,
            body: "Failed to send email"
        };
    }
};