import * as admin from "firebase-admin";

admin.initializeApp();

export { onChatMessageCreated } from "./chat";
export {
  onTaskCreated,
  onTaskUpdated,
  onTaskApprovedAwardPoints,
} from "./tasks";
export { onStoryCreated } from "./diary";
export { weeklyChampionRollup, bestMomentsRollup } from "./weekly";
export { aiQuizFromMemories } from "./ai";
export { onFamilyDemoModeWrite, onFamilyMemberJoinedDemoSeed } from "./demo_seed";
export { scheduledFamilyDigest, weeklyDigestReady } from "./reminders";
export { auditMemberStatsWrite } from "./stats_audit";
export { deleteAccount } from "./account";
export { verifySubscriptionPurchase, refreshSubscriptions } from "./billing";
export { resolveJoinCode, allocateJoinCode } from "./join_codes";
