// Questions judges can ask after a pitch (same as the printed Judge-Questions sheet).
export const QUESTIONS = [
  { tag: "Problem · Real-world value", q: "Who exactly has this problem, and how do you know it is real?",
    listen: "A specific user group, evidence (interviews, surveys, numbers, personal experience), and how people solve it today." },
  { tag: "Innovation · Creativity", q: "What makes your solution different from what already exists?",
    listen: "Named competitors or alternatives, and one clear advantage (cheaper, faster, local language, offline, AI, new business model)." },
  { tag: "Feasibility · Technical execution", q: "What part works today, and what is the hardest technical or practical challenge left?",
    listen: "An honest split between demo and plan, the tools used (Android Studio, Python/Java, database, APIs), and a realistic next step." },
  { tag: "Market · Business", q: "How will your project make money or stay sustainable, and who pays?",
    listen: "A clear customer, a price or revenue model (subscription, commission, ads, B2B), and a rough idea of costs." },
  { tag: "Impact · Growth", q: "If you had 6 months and some funding, what would you do first, and how would you measure success?",
    listen: "Concrete priorities, numbers (users, revenue, schools, cities), and social or economic impact for Uzbekistan." },
  { tag: "Team · Presentation", q: "What did each team member do, and what was the biggest thing you learned while building it?",
    listen: "Clear roles, real teamwork, reflection on mistakes, and confident answers from more than one member." },
];

export const FOLLOW_UPS = [
  ["Mobile apps", "Can you show the app running? How will you get your first 1,000 users?"],
  ["Websites", "How do you keep users' data safe? What happens when 1,000 people use it at once?"],
  ["Startup ideas", "What is the smallest version you could test next week, and with whom?"],
];
