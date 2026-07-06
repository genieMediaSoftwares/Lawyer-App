const Article = require("../../models/Article");
const ApiResponse = require("../../config/ApiResponse");

class ArticleController {
  async getArticles(req, res, next) {
    try {
      const { category, search } = req.query;
      let query = {};

      if (category && category !== "All") {
        query.category = { $regex: category, $options: "i" };
      }

      if (search) {
        query.$or = [
          { title: { $regex: search, $options: "i" } },
          { content: { $regex: search, $options: "i" } }
        ];
      }

      const articles = await Article.find(query).sort({ createdAt: -1 });
      return ApiResponse.success(res, "Articles fetched successfully.", articles);
    } catch (error) {
      next(error);
    }
  }

  async getArticleById(req, res, next) {
    try {
      const { id } = req.params;
      const article = await Article.findById(id);
      if (!article) {
        return ApiResponse.error(res, "Article not found.", 404);
      }
      return ApiResponse.success(res, "Article fetched successfully.", article);
    } catch (error) {
      next(error);
    }
  }

  async toggleBookmark(req, res, next) {
    try {
      const { id } = req.params;
      const userId = req.user._id;

      const article = await Article.findById(id);
      if (!article) {
        return ApiResponse.error(res, "Article not found.", 404);
      }

      const index = article.bookmarks.indexOf(userId);
      let bookmarked = false;

      if (index > -1) {
        article.bookmarks.splice(index, 1);
      } else {
        article.bookmarks.push(userId);
        bookmarked = true;
      }

      await article.save();
      return ApiResponse.success(res, "Article bookmark status toggled.", { bookmarked });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ArticleController();
