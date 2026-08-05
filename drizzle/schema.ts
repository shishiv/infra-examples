import { relations } from 'drizzle-orm';
import {
  boolean,
  customType,
  integer,
  pgSchema,
  primaryKey,
  text,
  timestamp,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

// Schema boundary for the public portfolio contract.
const portfolioExample = pgSchema('example');

const postStatusEnum = portfolioExample.enum('post_status', [
  'draft',
  'published',
  'archived',
]);

/** A contact record shape. This file contains no contact records. */
export const leads = portfolioExample.table('leads', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: varchar('name').notNull(),
  email: varchar('email').notNull().unique(),
  company: varchar('company'),
  phone: varchar('phone'),
  message: text('message').notNull(),
  source: varchar('source').notNull().default('landing-page'),
  newsletter_opt_in: boolean('newsletter_opt_in').default(false).notNull(),
  repeated_contact: boolean('repeated_contact').default(false).notNull(),
  created_at: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updated_at: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

/** An author record shape. This file contains no author records. */
export const authors = portfolioExample.table('authors', {
  id: uuid('id').defaultRandom().primaryKey(),
  slug: varchar('slug').notNull().unique(),
  name: varchar('name').notNull(),
  role: varchar('role').notNull(),
  bio: text('bio').notNull(),
  avatar_url: varchar('avatar_url'),
  linkedin_url: varchar('linkedin_url'),
  created_at: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updated_at: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

/** A content category record shape. */
export const categories = portfolioExample.table('categories', {
  id: uuid('id').defaultRandom().primaryKey(),
  slug: varchar('slug').notNull().unique(),
  name: varchar('name').notNull(),
  description: text('description'),
  created_at: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updated_at: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

const tsvector = customType<{ data: string }>({
  dataType() {
    return 'tsvector';
  },
});

/** A content post with explicit author and category relationships. */
export const posts = portfolioExample.table('posts', {
  id: uuid('id').defaultRandom().primaryKey(),
  slug: varchar('slug').notNull().unique(),
  title: varchar('title').notNull(),
  excerpt: text('excerpt').notNull(),
  content: text('content').notNull(),
  featured_image_url: varchar('featured_image_url').notNull(),
  author_id: uuid('author_id')
    .notNull()
    .references(() => authors.id),
  category_id: uuid('category_id')
    .notNull()
    .references(() => categories.id),
  status: postStatusEnum('status').notNull().default('draft'),
  meta_title: varchar('meta_title'),
  meta_description: varchar('meta_description'),
  reading_time_minutes: integer('reading_time_minutes').notNull().default(1),
  published_at: timestamp('published_at', { withTimezone: true }),
  created_at: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updated_at: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  search_vector: tsvector('search_vector'),
});

/** A tag record shape. */
export const tags = portfolioExample.table('tags', {
  id: uuid('id').defaultRandom().primaryKey(),
  slug: varchar('slug').notNull().unique(),
  name: varchar('name').notNull(),
  created_at: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

/** The many-to-many post/tag join table with a composite primary key. */
export const postTags = portfolioExample.table(
  'post_tags',
  {
    post_id: uuid('post_id')
      .notNull()
      .references(() => posts.id),
    tag_id: uuid('tag_id')
      .notNull()
      .references(() => tags.id),
  },
  (table) => [primaryKey({ columns: [table.post_id, table.tag_id] })],
);

export type NewLead = typeof leads.$inferInsert;
export type Lead = typeof leads.$inferSelect;
export type NewPost = typeof posts.$inferInsert;
export type Post = typeof posts.$inferSelect;
export type NewCategory = typeof categories.$inferInsert;
export type Category = typeof categories.$inferSelect;
export type NewAuthor = typeof authors.$inferInsert;
export type Author = typeof authors.$inferSelect;

export const postsRelations = relations(posts, ({ one, many }) => ({
  author: one(authors, {
    fields: [posts.author_id],
    references: [authors.id],
  }),
  category: one(categories, {
    fields: [posts.category_id],
    references: [categories.id],
  }),
  postTags: many(postTags),
}));

export const postTagsRelations = relations(postTags, ({ one }) => ({
  post: one(posts, {
    fields: [postTags.post_id],
    references: [posts.id],
  }),
  tag: one(tags, {
    fields: [postTags.tag_id],
    references: [tags.id],
  }),
}));
