import { onDocumentCreated } from "firebase-functions/v2/firestore";

import { REGION } from "./constants";
import { sendToFamily } from "./push";

export const onStoryCreated = onDocumentCreated(
  { document: "families/{familyId}/stories/{storyId}", region: REGION },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const authorUid: string = data.authorUid ?? "";
    const authorName: string = data.authorName ?? "Family";
    const title: string = data.title ?? "";
    const body: string = data.body ?? "";
    const mood: string = data.mood ?? "happy";

    const preview =
      title.trim().length > 0
        ? title
        : body.length > 80
          ? `${body.slice(0, 77)}...`
          : body;

    await sendToFamily(
      event.params.familyId,
      {
        title: `${authorName} added a memory`,
        body: preview.length > 0 ? preview : "Tap to read the new diary entry",
        data: {
          route: "/home",
          tab: "diary",
          storyId: event.params.storyId,
          mood,
        },
      },
      authorUid,
    );
  },
);
