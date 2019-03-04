const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// // Create and Deploy Your First Cloud Functions
// // https://firebase.google.com/docs/functions/write-firebase-functions
//
// exports.helloWorld = functions.https.onRequest((request, response) => {
//  response.send("Hello from Firebase!");
// });

exports.newMessage = functions.firestore.document('chat/{id}').onCreate((snap, context) => {
    const user = snap.data().user;
    const msg = snap.data().msg;

    admin.messaging().send({
        notification: {
            title: user,
            body: msg
        },
        android: {
            collapseKey: "collapse",
            priority: "normal",
            notification: {
                tag: "message"
            }
        },
        condition: "!('sent' in topics)"
    });
})