import { onDocumentCreated } from "firebase-functions/v2/firestore";

import { FAMILY_CHAT_ID, REGION } from "./constants";
import { sendToFamily } from "./push";

/**
 * On every new chat message in the single family chat, push the message body
 * to all other family members. Reactions and reads are NOT pushed.
 */
export const onChatMessageCreated = onDocumentCreated(
  {
    document: `families/{familyId}/chats/${FAMILY_CHAT_ID}/messages/{messageId}`,
    region: REGION,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const authorUid: string = data.authorUid ?? "";
    const authorName: string = data.authorName ?? "Family";
    const type: string = data.type ?? "text";
    const text: string = data.text ?? "";

    let body: string;
    if (type === "voice") {
      body = "Sent a voice note";
    } else {
      body = text.length > 140 ? `${text.slice(0, 137)}...` : text;
    }

    if (!body || body.trim().length === 0) return;

    await sendToFamily(
      event.params.familyId,
      {
        title: authorName,
        body,
        data: {
          route: "/home",
          tab: "chat",
          messageId: event.params.messageId,
        },
      },
      authorUid,
    );
  },
);
